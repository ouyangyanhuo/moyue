import 'package:moyue_application/models/feed_models.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/storage/storage_backend_base.dart';

MoyueStorageBackend createStorageBackend() => _MemoryStorageBackend();

class _MemoryStorageBackend implements MoyueStorageBackend {
  final List<ReadingDocument> _documents = [];
  final List<FeedSource> _sources = [];
  final Map<String, String> _feeds = {};

  @override
  Future<List<ReadingDocument>> loadDocuments() async => List.of(_documents);

  @override
  Future<ReadingDocument> writeDocument({
    required String title,
    required String content,
    required DocumentKind kind,
    String? existingPath,
  }) async {
    final now = DateTime.now();
    final path =
        existingPath ??
        'memory://${now.microsecondsSinceEpoch}.${kind.extension}';
    final document = ReadingDocument(
      id: path,
      title: title,
      content: content,
      kind: kind,
      updatedAt: now,
      filePath: path,
    );
    _documents.removeWhere((item) => item.filePath == path);
    _documents.insert(0, document);
    return document;
  }

  @override
  Future<void> deleteDocument(ReadingDocument document) async =>
      _documents.removeWhere((item) => item.id == document.id);

  @override
  Future<List<FeedSource>> loadFeedSources() async => List.of(_sources);

  @override
  Future<void> saveFeedSources(List<FeedSource> sources) async {
    _sources
      ..clear()
      ..addAll(sources);
  }

  @override
  Future<String> writeFeedXml(FeedSource source, String xml) async {
    final path = 'memory://${source.id}.xml';
    _feeds[path] = xml;
    return path;
  }

  @override
  Future<String?> readFeedXml(FeedSource source) async =>
      source.rawFilePath == null ? null : _feeds[source.rawFilePath];

  @override
  Future<void> deleteFeed(FeedSource source) async {
    if (source.rawFilePath != null) _feeds.remove(source.rawFilePath);
    _sources.removeWhere((item) => item.id == source.id);
  }
}
