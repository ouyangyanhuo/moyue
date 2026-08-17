class FolderRecord {
  const FolderRecord({
    required this.id,
    required this.category,
    required this.name,
    required this.single,
    required this.marker,
    required this.relativePath,
    required this.entryCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String category;
  final String name;
  final bool single;
  final String marker;
  final String relativePath;
  final int entryCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'category': category,
    'name': name,
    'single': single ? 1 : 0,
    'marker': marker,
    'relative_path': relativePath,
    'entry_count': entryCount,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };
}

class DocumentRecord {
  const DocumentRecord({
    required this.id,
    required this.folderId,
    required this.name,
    required this.kind,
    required this.relativePath,
    required this.isPrimary,
    required this.contentHash,
    required this.createdAt,
    required this.updatedAt,
    this.sourceUrl,
  });

  final String id;
  final String folderId;
  final String name;
  final String kind;
  final String relativePath;
  final bool isPrimary;
  final String contentHash;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sourceUrl;

  Map<String, Object?> toMap() => {
    'id': id,
    'folder_id': folderId,
    'name': name,
    'kind': kind,
    'relative_path': relativePath,
    'is_primary': isPrimary ? 1 : 0,
    'content_hash': contentHash,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'source_url': sourceUrl,
  };
}

class ResourceRecord {
  const ResourceRecord({
    required this.id,
    required this.folderId,
    required this.documentId,
    required this.name,
    required this.mimeType,
    required this.relativePath,
    required this.contentHash,
    required this.sizeBytes,
  });

  final String id;
  final String folderId;
  final String? documentId;
  final String name;
  final String mimeType;
  final String relativePath;
  final String contentHash;
  final int sizeBytes;

  Map<String, Object?> toMap() => {
    'id': id,
    'folder_id': folderId,
    'document_id': documentId,
    'name': name,
    'mime_type': mimeType,
    'relative_path': relativePath,
    'content_hash': contentHash,
    'size_bytes': sizeBytes,
  };
}
