import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:moyue_application/services/storage/package_file_store_base.dart';
import 'package:path/path.dart' as p;

PackageFileStore createPackageFileStore() => _IoPackageFileStore();

class _IoPackageFileStore implements PackageFileStore {
  static const _channel = MethodChannel('com.moyue.application/storage');
  Directory? _cachedRoot;

  Future<Directory> _root() async {
    if (_cachedRoot case final root?) return root;
    String path;
    if (Platform.isAndroid) {
      try {
        path =
            await _channel.invokeMethod<String>('externalFilesDir') ??
            Directory.systemTemp.path;
      } on MissingPluginException {
        path = p.join(Directory.systemTemp.path, 'moyue_test_data');
      }
    } else if (Platform.isWindows) {
      path = p.join(
        Platform.environment['APPDATA'] ?? Directory.current.path,
        'Moyue',
      );
    } else {
      path = p.join(
        Platform.environment['HOME'] ?? Directory.current.path,
        '.moyue',
      );
    }
    final root = Directory(path);
    await root.create(recursive: true);
    return _cachedRoot = root;
  }

  @override
  Future<String> databasePath() async =>
      p.join((await _root()).path, 'moyue_index.db');

  @override
  Future<void> createFolder(String relativePath) async {
    final directory = Directory(
      _safeTarget((await _root()).path, relativePath).path,
    );
    await directory.create(recursive: true);
  }

  @override
  Future<void> writeFiles(Map<String, Uint8List> files) async {
    final root = await _root();
    for (final entry in files.entries) {
      final target = _safeTarget(root.path, entry.key);
      await target.parent.create(recursive: true);
      await target.writeAsBytes(entry.value, flush: true);
    }
  }

  @override
  Future<Uint8List> readBytes(String relativePath) async =>
      File(_safeTarget((await _root()).path, relativePath).path).readAsBytes();

  @override
  Future<String> readText(String relativePath) async =>
      utf8.decode(await readBytes(relativePath), allowMalformed: true);

  @override
  Future<void> deleteFile(String relativePath) async {
    final file = _safeTarget((await _root()).path, relativePath);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> deleteFolder(String relativePath) async {
    final directory = Directory(
      _safeTarget((await _root()).path, relativePath).path,
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  @override
  Future<List<String>> listFiles(String relativeDir) async {
    final root = (await _root()).path;
    final directory = Directory(_safeTarget(root, relativeDir).path);
    if (!await directory.exists()) return const [];
    final names = <String>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      names.add(p.relative(entity.path, from: root).replaceAll(r'\', '/'));
    }
    names.sort();
    return names;
  }

  File _safeTarget(String root, String relativePath) {
    final normalized = p.normalize(p.join(root, relativePath));
    if (!p.isWithin(root, normalized)) {
      throw const FormatException('压缩包包含不安全路径');
    }
    return File(normalized);
  }
}
