import 'package:moyue_application/models/reading_document.dart';

class LibraryFolder {
  const LibraryFolder({
    required this.id,
    required this.name,
    required this.documents,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<ReadingDocument> documents;
  final DateTime updatedAt;

  LibraryFolder copyWith({
    String? name,
    List<ReadingDocument>? documents,
    DateTime? updatedAt,
  }) => LibraryFolder(
    id: id,
    name: name ?? this.name,
    documents: documents ?? this.documents,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
