import 'package:moyue_application/models/feed_models.dart';
import 'package:moyue_application/models/reading_document.dart';

abstract interface class MoyueStorageBackend {
  Future<List<ReadingDocument>> loadDocuments();

  Future<ReadingDocument> writeDocument({
    required String title,
    required String content,
    required DocumentKind kind,
    String? existingPath,
  });

  Future<void> deleteDocument(ReadingDocument document);

  Future<List<FeedSource>> loadFeedSources();

  Future<void> saveFeedSources(List<FeedSource> sources);

  Future<String> writeFeedXml(FeedSource source, String xml);

  Future<String?> readFeedXml(FeedSource source);

  Future<void> deleteFeed(FeedSource source);
}
