import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class FileUtil {
  static const FileUtil _self = FileUtil._internal();

  factory FileUtil() {
    return _self;
  }

  const FileUtil._internal();

  String tempFile({String suffix = 'tmp'}) {
    if (!suffix.startsWith('.')) {
      suffix = '.$suffix';
    }
    var uuid = Uuid();
    var path = '${join(Directory.systemTemp.path, uuid.v4())}$suffix';
    touch(path);
    return path;
  }

  String? fileExtension(String? path) {
    return path != null ? extension(path) : null;
  }

  bool exists(String path) {
    var fout = File(path);
    return fout.existsSync();
  }

  bool directoryExists(String path) {
    return Directory(path).existsSync();
  }

  void delete(String path) {
    var fout = File(path);
    fout.deleteSync();
  }

  void truncate(String path) {
    RandomAccessFile? raf;

    try {
      var file = File(path);
      raf = file.openSync(mode: FileMode.write);
      raf.truncateSync(0);
    } finally {
      if (raf != null) raf.closeSync();
    }
  }

  void touch(String path) {
    final file = File(path);
    file.createSync();
  }

  bool isFile(String path) {
    var fromType = FileSystemEntity.typeSync(path);
    return (fromType == FileSystemEntityType.file);
  }

  int fileLength(String path) {
    return File(path).lengthSync();
  }

  Future<Uint8List> readIntoBuffer(String path) {
    return File(path).readAsBytes();
  }
}
