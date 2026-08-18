import 'dart:typed_data';

abstract interface class PackageFileStore {
  Future<String> databasePath();
  Future<void> createFolder(String relativePath);
  Future<void> writeFiles(Map<String, Uint8List> files);
  Future<Uint8List> readBytes(String relativePath);
  Future<String> readText(String relativePath);
  Future<void> deleteFile(String relativePath);
  Future<void> deleteFolder(String relativePath);
}
