import 'dart:async';
import 'dart:typed_data';

import 'package:iris_sound_player/soundPlayer/audio.dart';
import 'package:iris_sound_player/soundPlayer/playback_disposition.dart';
import 'package:iris_sound_player/soundPlayer/file_util.dart' as fm;

typedef TrackAction = void Function(Track current);
///=======================================================================================
class Track {
  late final TrackStorageType _storageType;
  late final Audio _audio;
  String title = '';
  String artist = '';
  String album = '';
  String albumArtUrl = '';
  String albumArtAsset = '';
  String albumArtFile = '';

  int get length => _audio.length;

  @override
  String toString() {
    return '$title  $artist  audio: $_audio';
  }

  Track.fromFile(String path) {
    if (!fm.FileUtil().exists(path)) {
      throw TrackPathException('The given path $path does not exist.');
    }

    if (!fm.FileUtil().isFile(path)) {
      throw TrackPathException('The given path $path is not a file.');
    }

    _storageType = TrackStorageType.file;

    _audio = Audio.fromFile(path);
  }

  Track.fromAsset(String assetPath) {
    _storageType = TrackStorageType.asset;

    _audio = Audio.fromAsset(assetPath);
  }

  Track.fromURL(String url) {
    _storageType = TrackStorageType.url;

    _audio = Audio.fromURL(url);
  }

  Track.fromBuffer(Uint8List? buffer) {
    buffer ??= Uint8List(0);

    _storageType = TrackStorageType.buffer;
    _audio = Audio.fromBuffer(buffer);
  }

  bool get isURL => _storageType == TrackStorageType.url;

  bool get isFile => _storageType == TrackStorageType.file;

  bool get isAsset => _storageType == TrackStorageType.file;

  bool get isBuffer => _storageType == TrackStorageType.buffer;

  String? get url => _audio.url;

  String? get path => _audio.path;

  Uint8List? get buffer => _audio.buffer;

  Future<Uint8List> get asBuffer => _audio.asBuffer;

  String get identity {
    if (isFile)
      return path!;

    if (isURL)
      return url!;

    return '${_audio.buffer.hashCode}';
  }

  void _release() => _audio.release();

  Future _prepareStream(LoadingProgress progress) async =>
      _audio.prepareStream(progress);

  static String tempFile() {
    return fm.FileUtil().tempFile();
  }

  static Track end = Track.fromURL('http://end.mp3');
}
///=======================================================================================
void trackRelease(Track track) => track._release();
///=======================================================================================
Future prepareStream(Track track, LoadingProgress progress) =>
    track._prepareStream(progress);
///=======================================================================================
String trackStoragePath(Track track) {
  if (track._audio.onDisk) {
    return track._audio.storagePath;
  }
  else {
    assert(track.isURL);
    return track.url!;
  }
}
///=======================================================================================
Uint8List? trackBuffer(Track track) => track._audio.buffer;
///=======================================================================================
class TrackPathException implements Exception {
  String message;
  TrackPathException(this.message);

  @override
  String toString() => message;
}
///=======================================================================================
enum TrackStorageType {
  asset,
  buffer,
  file,
  url
}