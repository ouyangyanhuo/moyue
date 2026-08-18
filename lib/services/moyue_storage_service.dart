import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:moyue_application/models/feed_models.dart';
import 'package:moyue_application/models/library_folder.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/document_package_service.dart';
import 'package:moyue_application/services/storage/storage_backend.dart';
import 'package:moyue_application/services/storage/storage_backend_base.dart';

class MoyueStorageService extends ChangeNotifier {
  MoyueStorageService._() : _backend = createStorageBackend();

  static final instance = MoyueStorageService._();
  final MoyueStorageBackend _backend;
  final DocumentPackageService _packages = DocumentPackageService();

  Future<List<ReadingDocument>> loadDocuments() async {
    final indexed = await _packages.loadDocuments();
    final legacy = await _backend.loadDocuments();
    return [...indexed, ...legacy]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<List<LibraryFolder>> loadFolders() => _packages.loadFolders();

  Future<void> createFolder(String name) async {
    await _packages.createFolder(name);
    notifyListeners();
  }

  Future<void> deleteFolder(LibraryFolder folder) async {
    await _packages.deleteFolderById(folder.id);
    notifyListeners();
  }

  Future<void> renameFolder(LibraryFolder folder, String name) async {
    await _packages.renameFolder(folder.id, name);
    notifyListeners();
  }

  Future<ReadingDocument> importIntoFolder({
    required LibraryFolder folder,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final document = await _packages.importIntoFolder(
      folder: folder,
      fileName: fileName,
      bytes: bytes,
    );
    notifyListeners();
    return document;
  }

  Future<ReadingDocument> saveDocument({
    required String title,
    required String content,
    required DocumentKind kind,
    ReadingDocument? existingDocument,
  }) async {
    final result = kind == DocumentKind.markdown
        ? await _packages.saveMarkdown(
            title: title,
            content: content,
            existing: existingDocument,
          )
        : await _packages.importFile(
            '$title.html',
            Uint8List.fromList(utf8.encode(content)),
          );
    if (existingDocument != null && existingDocument.folderId == null) {
      await _backend.deleteDocument(existingDocument);
    }
    notifyListeners();
    return result;
  }

  Future<ReadingDocument> importDocumentPackage({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final document = await _packages.importFile(fileName, bytes);
    notifyListeners();
    return document;
  }

  Future<MoyueExport> exportMoyue(ReadingDocument document) =>
      _packages.exportMoyue(document);

  Future<Uint8List?> readLinkedResource(
    ReadingDocument document,
    String link,
  ) => _packages.readLinkedResource(document, link);

  Future<void> deleteDocument(ReadingDocument document) async {
    if (document.folderId == null) {
      await _backend.deleteDocument(document);
    } else {
      await _packages.deleteDocument(document);
    }
    notifyListeners();
  }

  Future<List<FeedSource>> loadFeedSources() => _packages.loadFeedSources();
  Future<String?> readFeedXml(FeedSource source) => _packages.readFeed(source);

  Future<void> saveFeedSources(List<FeedSource> sources) async {
    for (final source in sources) {
      final existing = await _packages.readFeed(source) ?? '';
      await _packages.saveFeed(source, existing);
    }
    notifyListeners();
  }

  Future<FeedSource> saveFeedXml(FeedSource source, String xml) async {
    return _packages.saveFeed(source, xml);
  }

  Future<void> deleteFeed(FeedSource source) async {
    await _packages.deleteFeed(source);
    notifyListeners();
  }
}
