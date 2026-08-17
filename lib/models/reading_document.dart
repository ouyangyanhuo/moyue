enum DocumentKind {
  markdown('Markdown', 'md'),
  html('HTML', 'html');

  const DocumentKind(this.label, this.extension);
  final String label;
  final String extension;
}

class ReadingDocument {
  const ReadingDocument({
    required this.id,
    required this.title,
    required this.content,
    required this.kind,
    required this.updatedAt,
    this.sourceLabel = '本地文件',
    this.filePath,
  });

  final String id;
  final String title;
  final String content;
  final DocumentKind kind;
  final DateTime updatedAt;
  final String sourceLabel;
  final String? filePath;

  ReadingDocument copyWith({
    String? id,
    String? title,
    String? content,
    DocumentKind? kind,
    DateTime? updatedAt,
    String? sourceLabel,
    String? filePath,
  }) => ReadingDocument(
    id: id ?? this.id,
    title: title ?? this.title,
    content: content ?? this.content,
    kind: kind ?? this.kind,
    updatedAt: updatedAt ?? this.updatedAt,
    sourceLabel: sourceLabel ?? this.sourceLabel,
    filePath: filePath ?? this.filePath,
  );
}
