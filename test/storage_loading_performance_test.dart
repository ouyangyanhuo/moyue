import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/features/editor/editor_page.dart';
import 'package:moyue_application/models/library_folder.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/document_package_service.dart';
import 'package:moyue_application/services/moyue_storage_service.dart';
import 'package:moyue_application/services/storage/storage_backend_base.dart';
import 'package:moyue_application/services/system_share_service.dart';
import 'package:moyue_application/widgets/document_content_loader.dart';
import 'package:share_plus/share_plus.dart';

ReadingDocument _document() => ReadingDocument(
  id: 'doc',
  title: '标题',
  content: '正文',
  kind: DocumentKind.markdown,
  updatedAt: DateTime(2026),
  folderId: 'folder',
  relativePath: 'markdown/folder/doc.md',
);

class _Packages extends DocumentPackageService {
  int listReads = 0;
  int folderReads = 0;
  int cleanups = 0;
  final saved = <String>[];
  Completer<void>? saveGate;
  ReadingDocument document = _document();

  @override
  Future<List<ReadingDocument>> loadDocuments({
    bool includeContent = true,
  }) async {
    expect(includeContent, isFalse);
    listReads++;
    return [document.metadata];
  }

  @override
  Future<List<LibraryFolder>> loadFolders({bool includeContent = true}) async {
    expect(includeContent, isFalse);
    folderReads++;
    return [];
  }

  @override
  Future<ReadingDocument> saveMarkdown({
    required String title,
    required String content,
    ReadingDocument? existing,
  }) async {
    saved.add(content);
    await saveGate?.future;
    document = document.copyWith(
      title: title,
      content: content,
      updatedAt: DateTime(2026, 9, 27),
    );
    return document;
  }

  @override
  Future<int> cleanupUnreferencedImages(
    ReadingDocument document, {
    String? pendingContent,
  }) async {
    cleanups++;
    return 0;
  }
}

class _Backend implements MoyueStorageBackend {
  @override
  Future<List<ReadingDocument>> loadDocuments({
    bool includeContent = true,
  }) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('旧文档元数据打开和分享时读取完整中文正文，缺失文件不挂载编辑器', (tester) async {
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('moyue-lazy-open-'),
    ))!;
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/中文.md');
    const content = '# 中文标题\n\n完整正文，不是空白文件。';
    await tester.runAsync(() => file.writeAsString(content));
    final entry = ReadingDocument(
      id: file.path,
      title: '中文',
      content: '',
      contentLoaded: false,
      kind: DocumentKind.markdown,
      updatedAt: DateTime(2026),
      filePath: file.path,
    );
    // Start real file I/O outside the widget test's fake async zone.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentContentLoader(
            document: entry,
            builder: (loaded) => Scaffold(body: Text(loaded.content)),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text(content), findsOneWidget);
    final context = tester.element(find.text(content));
    final sharedBodies = <String>[];
    SystemShareService.debugShareOverride = (params) async {
      sharedBodies.add(utf8.decode(await params.files!.single.readAsBytes()));
      return const ShareResult('test', ShareResultStatus.success);
    };
    addTearDown(() => SystemShareService.debugShareOverride = null);
    await tester.runAsync(() async {
      await SystemShareService.shareDocument(context, entry);
      if (!context.mounted) return;
      await SystemShareService.shareSelection(context, documents: [entry]);
    });
    expect(sharedBodies, [content, content]);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(file.delete);
    var built = false;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentContentLoader(
            document: entry,
            builder: (_) {
              built = true;
              return const SizedBox();
            },
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(built, isFalse);
    expect(find.text('无法读取文档，请确认文件存在后重试。'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('索引请求合并，保存通知提供精确文档且不主动重新读取索引', () async {
    final packages = _Packages();
    final service = MoyueStorageService.forTesting(
      backend: _Backend(),
      packages: packages,
    );
    addTearDown(service.dispose);
    await Future.wait([
      service.loadDocuments(),
      service.loadDocuments(),
      service.loadFolders(),
      service.loadFolders(),
    ]);
    expect(packages.listReads, 1);
    expect(packages.folderReads, 1);
    ReadingDocument? change;
    service.addListener(() => change = service.changedDocument);
    await service.saveDocument(
      title: '新标题',
      content: '新正文',
      kind: DocumentKind.markdown,
      existingDocument: packages.document,
    );
    expect(change?.content, '新正文');
    expect(change?.id, 'doc');
    expect(service.changedDocument, isNull);
    expect(packages.listReads, 1);
    expect(packages.folderReads, 1);
    expect((await service.loadDocuments()).single.title, '新标题');
    expect(packages.listReads, 2);
  });

  test('空正文和未加载正文有不同状态，文件夹仅替换目标索引', () {
    final loaded = _document().copyWith(content: '');
    expect(loaded.contentLoaded, isTrue);
    expect(loaded.metadata.contentLoaded, isFalse);
    final folder = LibraryFolder(
      id: 'folder',
      name: '目录',
      documents: [_document()],
      updatedAt: DateTime(2026),
    );
    final next = folder.updateDocument(_document().copyWith(title: '重命名'));
    expect(next.documents.single.title, '重命名');
    expect(next.documents.single.contentLoaded, isFalse);
    expect(folder.documents.single.title, '标题');
  });

  testWidgets('编辑器光标和选区不保存；写入期间的新输入保留并再次保存', (tester) async {
    const channel = MethodChannel('com.moyue.application/system');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => false,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final packages = _Packages();
    final service = MoyueStorageService.forTesting(
      backend: _Backend(),
      packages: packages,
    );
    final display = MoyueDisplayPreferences();
    addTearDown(service.dispose);
    addTearDown(display.dispose);
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: MaterialApp(
          home: MarkdownEditorPage(
            document: packages.document,
            storage: service,
          ),
        ),
      ),
    );
    await tester.pump();
    final body = tester
        .widget<TextField>(find.byType(TextField).last)
        .controller!;
    body.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
    await tester.pump(const Duration(seconds: 2));
    expect(packages.saved, isEmpty);
    final gate = Completer<void>();
    packages.saveGate = gate;
    body.text = '第一次编辑';
    await tester.pump(const Duration(milliseconds: 950));
    expect(packages.saved, ['第一次编辑']);
    body.text = '保存期间继续编辑';
    gate.complete();
    await tester.pump();
    packages.saveGate = null;
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump();
    expect(packages.saved, ['第一次编辑', '保存期间继续编辑']);
    expect(packages.cleanups, 0);
    body.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump(const Duration(seconds: 2));
    expect(packages.saved, hasLength(2));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
