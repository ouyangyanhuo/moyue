import 'dart:typed_data';

abstract interface class PackageFileStore {
  Future<String> databasePath();
  Future<void> createFolder(String relativePath);
  Future<void> writeFiles(Map<String, Uint8List> files);
  Future<Uint8List> readBytes(String relativePath);
  Future<String> readText(String relativePath);
  Future<void> deleteFile(String relativePath);
  Future<void> deleteFolder(String relativePath);

  /// 列出 [relativeDir] 目录下的直接文件（不含子目录），
  /// 返回相对应用数据根的路径，使用 `/` 分隔；目录不存在时返回空列表。
  Future<List<String>> listFiles(String relativeDir);
}
