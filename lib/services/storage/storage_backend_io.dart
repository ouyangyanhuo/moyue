import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:moyue_application/models/feed_models.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/storage/storage_backend_base.dart';

MoyueStorageBackend createStorageBackend() => _IoStorageBackend();

class _IoStorageBackend implements MoyueStorageBackend {
  static const _channel = MethodChannel('com.moyue.application/storage');

  Future<Directory> _root() async {
    String root;
    if (Platform.isAndroid) {
      try {
        root =
            await _channel.invokeMethod<String>('externalFilesDir') ??
            Directory.systemTemp.path;
      } on MissingPluginException {
        root =
            '${Directory.systemTemp.path}${Platform.pathSeparator}moyue_test_data';
      }
    } else if (Platform.isWindows) {
      root =
          '${Platform.environment['APPDATA'] ?? Directory.current.path}'
          '${Platform.pathSeparator}Moyue';
    } else {
      root =
          '${Platform.environment['HOME'] ?? Directory.current.path}'
          '${Platform.pathSeparator}.moyue';
    }
    final directory = Directory(root);
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> _category(String name) async {
    final root = await _root();
    final directory = Directory('${root.path}${Platform.pathSeparator}$name');
    await directory.create(recursive: true);
    return directory;
  }

  String _safeName(String value) {
    final clean = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return clean.isEmpty ? '未命名文稿' : clean;
  }

  @override
  Future<List<ReadingDocument>> loadDocuments() async {
    final result = <ReadingDocument>[];
    for (final kind in DocumentKind.values) {
      final directory = await _category(
        kind == DocumentKind.markdown ? 'markdown' : 'html',
      );
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        final extension = entity.path.split('.').last.toLowerCase();
        final allowed = kind == DocumentKind.markdown
            ? extension == 'md' || extension == 'markdown'
            : extension == 'html' || extension == 'htm';
        if (!allowed) continue;
        final stat = await entity.stat();
        final name = entity.uri.pathSegments.last.replaceFirst(
          RegExp(r'\.[^.]+$'),
          '',
        );
        result.add(
          ReadingDocument(
            id: entity.path,
            title: Uri.decodeComponent(name),
            content: await entity.readAsString(),
            kind: kind,
            updatedAt: stat.modified,
            filePath: entity.path,
          ),
        );
      }
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  @override
  Future<ReadingDocument> writeDocument({
    required String title,
    required String content,
    required DocumentKind kind,
    String? existingPath,
  }) async {
    final directory = await _category(
      kind == DocumentKind.markdown ? 'markdown' : 'html',
    );
    var path =
        existingPath ??
        '${directory.path}${Platform.pathSeparator}${_safeName(title)}.${kind.extension}';
    if (existingPath == null) {
      var copy = 2;
      while (await File(path).exists()) {
        path =
            '${directory.path}${Platform.pathSeparator}${_safeName(title)} ($copy).${kind.extension}';
        copy++;
      }
    }
    final file = File(path);
    await file.writeAsString(content, flush: true);
    final stat = await file.stat();
    return ReadingDocument(
      id: path,
      title: title,
      content: content,
      kind: kind,
      updatedAt: stat.modified,
      filePath: path,
    );
  }

  @override
  Future<void> deleteDocument(ReadingDocument document) async {
    final path = document.filePath;
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<File> _subscriptionFile() async {
    final directory = await _category('rss');
    return File('${directory.path}${Platform.pathSeparator}subscriptions.json');
  }

  @override
  Future<List<FeedSource>> loadFeedSources() async {
    final file = await _subscriptionFile();
    if (!await file.exists()) return [];
    final values = jsonDecode(await file.readAsString()) as List<dynamic>;
    return values
        .map((value) {
          final map = value as Map<String, dynamic>;
          return FeedSource(
            id: map['id'] as String,
            title: map['title'] as String,
            url: Uri.parse(map['url'] as String),
            unreadCount: map['unreadCount'] as int? ?? 0,
            rawFilePath: map['rawFilePath'] as String?,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> saveFeedSources(List<FeedSource> sources) async {
    final file = await _subscriptionFile();
    final values = sources
        .map(
          (source) => {
            'id': source.id,
            'title': source.title,
            'url': source.url.toString(),
            'unreadCount': source.unreadCount,
            'rawFilePath': source.rawFilePath,
          },
        )
        .toList(growable: false);
    await file.writeAsString(jsonEncode(values), flush: true);
  }

  @override
  Future<String> writeFeedXml(FeedSource source, String xml) async {
    final directory = await _category('rss');
    final file = File(
      '${directory.path}${Platform.pathSeparator}${_safeName(source.id)}.xml',
    );
    await file.writeAsString(xml, flush: true);
    return file.path;
  }

  @override
  Future<String?> readFeedXml(FeedSource source) async {
    final path = source.rawFilePath;
    if (path == null) return null;
    final file = File(path);
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> deleteFeed(FeedSource source) async {
    final path = source.rawFilePath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }
}
