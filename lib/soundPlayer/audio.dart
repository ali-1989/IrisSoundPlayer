import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:iris_sound_player/soundPlayer/downloader.dart';
import 'package:iris_sound_player/soundPlayer/file_util.dart';
import 'package:iris_sound_player/soundPlayer/playback_disposition.dart';
import 'package:iris_sound_player/soundPlayer/temp_media_file.dart';
import 'package:iris_sound_player/soundPlayer/track.dart';


class Audio {
  final List<TempMediaFile> _tempMediaFiles = [];
  late final TrackStorageType _storageType;
  String? url;
  String? path;
  Uint8List? _dataBuffer;
  String? _storagePath;
  bool _onDisk = false;
  bool _prepared = false;

  bool get onDisk => _onDisk;

  Audio.fromFile(this.path) {
    _storageType = TrackStorageType.file;
    _storagePath = path;
    _onDisk = true;
  }

  Audio.fromAsset(this.path) {
    _storageType = TrackStorageType.asset;
    _dataBuffer = null;
    _onDisk = false;
  }

  Audio.fromURL(this.url) {
    _storageType = TrackStorageType.url;
  }

  Audio.fromBuffer(this._dataBuffer) {
    _storageType = TrackStorageType.buffer;
  }

  int get length {
    if (_onDisk) return File(_storagePath!).lengthSync();
    if (isBuffer) return _dataBuffer!.length;
    if (isFile) return File(path!).lengthSync();

    // if its a URL an asset and its not [_onDisk] then we don't
    // know its length.
    return 0;
  }

  Future<Uint8List> get asBuffer async {
    if (_dataBuffer != null) {
      return _dataBuffer!;
    }

    if (onDisk) {
      _dataBuffer = await FileUtil().readIntoBuffer(_storagePath!);
    }

    if (isURL) {
      TempMediaFile? tempMediaFile;
      try {
        tempMediaFile = TempMediaFile.empty();

        await Downloader.download(url!, tempMediaFile.path,
            progress: (disposition) {});

        _dataBuffer = await FileUtil().readIntoBuffer(tempMediaFile.path);
      } finally {
        tempMediaFile?.delete();
      }
    }

    return _dataBuffer!;
  }

  String get storagePath {
    assert(_onDisk);

    if (!_onDisk) throw AudioNotOnDiskException();

    return _storagePath!;
  }

  bool get isFile => _storageType == TrackStorageType.file;

  bool get isURL => _storageType == TrackStorageType.url;

  bool get isAsset => _storageType == TrackStorageType.asset;

  bool get isBuffer => _storageType == TrackStorageType.buffer;

  Uint8List? get buffer => _dataBuffer;

  Future prepareStream(LoadingProgress loadingProgress) async {
    if (_prepared) {
      return;
    }

    var stages = 1;
    var stage = 1;

    /// we can do no preparation for the url.
    if (isURL) {
      await _downloadURL((disposition) {
        _forwardStagedProgress(loadingProgress, disposition, stage, stages);
      });
      stage++;
    }

    if (isAsset) {
      await _loadAsset();
    }

    // android doesn't support data buffers so we must convert
    // to a file.
    // iOS doesn't support opus so we must convert to a file so we
    /// remux it.
    if ((Platform.isAndroid && isBuffer) || isAsset) {
      _writeBufferToDisk((disposition) {
        _forwardStagedProgress(loadingProgress, disposition, stage, stages);
      });
      stage++;
    }

    _prepared = true;
  }

  Future<void> _downloadURL(LoadingProgress progress) async {
    var saveToFile = TempMediaFile.empty();
    _tempMediaFiles.add(saveToFile);
    await Downloader.download(url!, saveToFile.path, progress: progress);
    _storagePath = saveToFile.path;
    _onDisk = true;
  }

  Future<void> _loadAsset() async {
    _dataBuffer = (await rootBundle.load(path!)).buffer.asUint8List();
  }

  void _writeBufferToDisk(LoadingProgress progress) {
    if (!_onDisk && _dataBuffer != null) {
      var tempMediaFile = TempMediaFile.fromBuffer(_dataBuffer!, progress);
      _tempMediaFiles.add(tempMediaFile);

      /// update the path to the new file.
      _storagePath = tempMediaFile.path;
      _onDisk = true;
    }
  }

  void _deleteTempFiles() {
    for (var tmp in _tempMediaFiles) {
      tmp.delete();
    }
    _tempMediaFiles.clear();
  }

  void release() {
    if (_tempMediaFiles.isNotEmpty) {
      _prepared = false;
      _onDisk = false;
      _deleteTempFiles();
    }
  }

  void _forwardStagedProgress(LoadingProgress loadingProgress,
      PlaybackDisposition disposition, int stage, int stages) {
    var rewritten = false;

    if (disposition.state == PlaybackDispositionState.loading) {
      // if we have 3 stages then a progress of 1.0 becomes progress
      /// 0.3.
      var progress = disposition.progress / stages;
      // offset the progress based on which stage we are in.
      progress += 1.0 / stages * (stage - 1);
      loadingProgress(PlaybackDisposition.loading(progress: progress));
      rewritten = true;
    }

    if (disposition.state == PlaybackDispositionState.loaded) {
      if (stage != stages) {
        /// if we are not the last stage change 'loaded' into loading.
        loadingProgress(
            PlaybackDisposition.loading(progress: stage * (1.0 / stages)));
        rewritten = true;
      }
    }
    if (!rewritten) {
      loadingProgress(disposition);
    }
  }

  @override
  String toString() {
    var desc = '';

    if (_onDisk) {
      desc += 'storage: $_storagePath';
    }

    if (isURL) desc += ' url: $url';
    if (isFile) desc += ' path: $path';
    if (isBuffer) {
      desc +=
          ' buffer len: ${_dataBuffer == null ? 'unknown' : '${_dataBuffer!.length}'}}';
    }
    if (isAsset) desc += ' asset: $path';

    return desc;
  }
}

class AudioNotOnDiskException implements Exception {
  AudioNotOnDiskException();

  @override
  String toString() => 'The Audio is not on disk. Did you pass it as a buffer?';
}
