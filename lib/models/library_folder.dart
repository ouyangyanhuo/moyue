import 'package:moyue_application/models/reading_document.dart';

class LibraryFolder {
  const LibraryFolder({
    required this.id,
    required this.name,
    required this.documents,
    required this.updatedAt,
    this.subfolderPaths = const [],
  });

  final String id;
  final String name;
  final List<ReadingDocument> documents;
  final DateTime updatedAt;

  /// 已持久化的空目录与非空目录，均为相对当前根文件夹的逻辑路径。
  final List<String> subfolderPaths;

  LibraryFolder updateDocument(ReadingDocument document) {
    if (!documents.any((item) => item.id == document.id)) return this;
    final updated = [
      for (final item in documents)
        item.id == document.id ? document.metadata : item,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return copyWith(documents: updated, updatedAt: document.updatedAt);
  }

  LibraryFolder copyWith({
    String? name,
    List<ReadingDocument>? documents,
    DateTime? updatedAt,
    List<String>? subfolderPaths,
  }) => LibraryFolder(
    id: id,
    name: name ?? this.name,
    documents: documents ?? this.documents,
    updatedAt: updatedAt ?? this.updatedAt,
    subfolderPaths: subfolderPaths ?? this.subfolderPaths,
  );
}
