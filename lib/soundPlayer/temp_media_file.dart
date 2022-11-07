
import 'dart:io';
import 'dart:typed_data';

import 'package:iris_sound_player/soundPlayer/playback_disposition.dart';
import 'file_util.dart' as fm;

class TempMediaFile {
  late final String path;
  bool _deleted = false;

  TempMediaFile(this.path);

  void delete() {
    if (_deleted) {
      throw TempMediaFileAlreadyDeletedException(
          'The file $path has already been deleted');
    }
    if (fm.FileUtil().exists(path)) fm.FileUtil().delete(path);
    _deleted = true;
  }

  TempMediaFile.empty() {
    path = fm.FileUtil().tempFile();
  }

  TempMediaFile.fromBuffer(
      Uint8List dataBuffer, LoadingProgress loadingProgress) {
    path = fm.FileUtil().tempFile();

    if (fm.FileUtil().exists(path)) {
      fm.FileUtil().delete(path);
    }

    var bytesWritten = 0;

    const packetSize = 4096;
    var file = File(path);
    var length = dataBuffer.length;
    var parts = length ~/ packetSize;
    var increment = 1.0 / parts;
    for (var i = 0; i < parts; i++) {
      var start = i * packetSize;
      var end = start + packetSize;
      file.writeAsBytesSync(dataBuffer.sublist(start, end),
          mode: FileMode.append); // Write
      bytesWritten += packetSize;
      var progress = i * increment;

      loadingProgress(PlaybackDisposition.loading(progress: progress));
    }
    // write final packet if there is a partial packet left
    if (bytesWritten != length) {
      file.writeAsBytesSync(dataBuffer.sublist(parts * packetSize, length),
          mode: FileMode.append);
      bytesWritten += length - (parts * packetSize);
    }
    assert(bytesWritten == length);
    loadingProgress(PlaybackDisposition.loaded());
  }
}
///=================================================================================================
class TempMediaFileAlreadyDeletedException implements Exception {
  final String _message;

  TempMediaFileAlreadyDeletedException(this._message);

  @override
  String toString() => _message;
}
