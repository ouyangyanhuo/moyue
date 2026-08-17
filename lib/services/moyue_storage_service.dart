import 'package:flutter/foundation.dart';
import 'package:moyue_application/models/feed_models.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/storage/storage_backend.dart';
import 'package:moyue_application/services/storage/storage_backend_base.dart';

class MoyueStorageService extends ChangeNotifier {
  MoyueStorageService._() : _backend = createStorageBackend();

  static final instance = MoyueStorageService._();
  final MoyueStorageBackend _backend;

  Future<List<ReadingDocument>> loadDocuments() => _backend.loadDocuments();

  Future<ReadingDocument> saveDocument({
    required String title,
    required String content,
    required DocumentKind kind,
    String? existingPath,
  }) async {
    final result = await _backend.writeDocument(
      title: title,
      content: content,
      kind: kind,
      existingPath: existingPath,
    );
    notifyListeners();
    return result;
  }

  Future<void> deleteDocument(ReadingDocument document) async {
    await _backend.deleteDocument(document);
    notifyListeners();
  }

  Future<List<FeedSource>> loadFeedSources() => _backend.loadFeedSources();
  Future<String?> readFeedXml(FeedSource source) =>
      _backend.readFeedXml(source);

  Future<void> saveFeedSources(List<FeedSource> sources) async {
    await _backend.saveFeedSources(sources);
    notifyListeners();
  }

  Future<FeedSource> saveFeedXml(FeedSource source, String xml) async {
    final path = await _backend.writeFeedXml(source, xml);
    return source.copyWith(rawFilePath: path);
  }

  Future<void> deleteFeed(FeedSource source) async {
    await _backend.deleteFeed(source);
    notifyListeners();
  }
}
