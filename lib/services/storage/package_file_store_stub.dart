import 'dart:convert';
import 'dart:typed_data';

import 'package:moyue_application/services/storage/package_file_store_base.dart';

PackageFileStore createPackageFileStore() => _WebPackageFileStore();

class _WebPackageFileStore implements PackageFileStore {
  static final Map<String, Uint8List> _files = {};

  @override
  Future<String> databasePath() async => 'moyue_index.db';

  @override
  Future<void> createFolder(String relativePath) async {}

  @override
  Future<void> writeFiles(Map<String, Uint8List> files) async =>
      _files.addAll(files);

  @override
  Future<Uint8List> readBytes(String relativePath) async {
    final value = _files[relativePath];
    if (value == null) throw StateError('资源不存在：$relativePath');
    return value;
  }

  @override
  Future<String> readText(String relativePath) async =>
      utf8.decode(await readBytes(relativePath), allowMalformed: true);

  @override
  Future<void> deleteFile(String relativePath) async {
    _files.remove(relativePath);
  }

  @override
  Future<void> deleteFolder(String relativePath) async {
    _files.removeWhere(
      (path, _) => path == relativePath || path.startsWith('$relativePath/'),
    );
  }

  @override
  Future<List<String>> listFiles(String relativeDir) async {
    final prefix = '$relativeDir/';
    return _files.keys
        .where((path) => path.startsWith(prefix))
        .where((path) => !path.substring(prefix.length).contains('/'))
        .toList()
      ..sort();
  }
}
