import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/features/reader/reader_detail_page.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/reading_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  const progress = ReadingProgress(
    offset: 650,
    extent: 1000,
    layout: 'old',
    textScale: 1.2,
  );

  test('阅读进度按 ID 隔离且可从新的服务实例读回', () async {
    final store = ReadingProgressService();
    final first = store.save('a/同名', progress);
    final second = store.save(
      'b/同名',
      const ReadingProgress(
        offset: 10,
        extent: 1000,
        layout: 'old',
        textScale: 1,
      ),
    );
    await Future.wait([first, second]);
    final restored = await ReadingProgressService().read('a/同名');
    expect(restored?.offset, 650);
    expect(restored?.textScale, 1.2);
    expect((await store.read('b/同名'))?.offset, 10);
    expect(await store.read('new'), isNull);
    expect(ReadingProgress.decode('{broken'), isNull);
    expect(
      ReadingProgress.decode(
        '{"version":1,"layout":"a","offset":-1,"extent":20,"textScale":1}',
      ),
      isNull,
    );
  });

  test('相同排版使用像素位置，排版改变按比例恢复且不越界', () {
    expect(progress.target(2000, 'old'), 650);
    expect(progress.target(2000, 'new'), 1300);
    expect(progress.target(100, 'old'), 100);
    expect(progress.target(0, 'new'), 0);
  });

  testWidgets('持续滚动合并写入且退出立即提交最后位置', (tester) async {
    final service = ReadingProgressService();
    final session = ReadingProgressSession('throttle', service);
    for (var i = 0; i < 20; i++) {
      session.record(
        ReadingProgress(
          offset: i.toDouble(),
          extent: 100,
          layout: 'a',
          textScale: 1,
        ),
      );
    }
    expect(await service.read('throttle'), isNull);
    await tester.pump(const Duration(milliseconds: 850));
    expect((await service.read('throttle'))?.offset, 19);
    session.record(progress);
    session.dispose();
    expect((await service.read('throttle'))?.offset, 650);
  });

  for (final mode in MarkdownRenderingMode.values) {
    testWidgets('Markdown ${mode.name} 退出重开恢复并允许用户继续向上阅读', (tester) async {
      final display = MoyueDisplayPreferences()..setMarkdownRenderingMode(mode);
      addTearDown(display.dispose);
      final doc = ReadingDocument(
        id: 'restore-${mode.name}',
        title: '相同名称.md',
        content: List.generate(
          160,
          (i) => '第 $i 段，这是用于阅读位置恢复的正文。',
        ).join('\n\n'),
        kind: DocumentKind.markdown,
        updatedAt: DateTime(2026),
      );
      Widget app(ReadingDocument document) => DisplayPreferencesScope(
        controller: display,
        child: MaterialApp(home: ReaderDetailPage(document: document)),
      );
      await tester.pumpWidget(app(doc));
      await tester.pumpAndSettle();
      await tester.drag(_verticalScroll(), const Offset(0, -1100));
      await tester.pumpAndSettle();
      final before = _position(tester).pixels;
      expect(before, greaterThan(900));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(
        (await ReadingProgressService.instance.read(doc.id))?.offset,
        closeTo(before, 1),
      );

      // Rename/move preserve the stable identity, and consequently its history.
      await tester.pumpWidget(
        app(doc.copyWith(title: '已重命名.md', folderId: 'moved')),
      );
      await tester.pumpAndSettle();
      expect(_position(tester).pixels, closeTo(before, 2));
      await tester.drag(_verticalScroll(), const Offset(0, 350));
      await tester.pumpAndSettle();
      final after = _position(tester).pixels;
      expect(after, lessThan(before));
      await tester.pump(const Duration(milliseconds: 1600));
      expect(_position(tester).pixels, closeTo(after, 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(
        (await ReadingProgressService.instance.read(doc.id))?.offset,
        closeTo(after, 1),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      await ReadingProgressService.instance.read(doc.id);
    });
  }

  testWidgets('原生 HTML 重开恢复；打开其他同名文档仍从顶部开始', (tester) async {
    final doc = ReadingDocument(
      id: 'html-progress',
      title: '相同名称',
      content: List.generate(100, (i) => '<p>HTML 第 $i 段正文。</p>').join(),
      kind: DocumentKind.html,
      updatedAt: DateTime(2026),
    );
    Future<void> open(ReadingDocument document) async {
      await tester.pumpWidget(
        MaterialApp(home: ReaderDetailPage(document: document)),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
    }

    await open(doc);
    await tester.drag(_verticalScroll(), const Offset(0, -800));
    await tester.pumpAndSettle();
    final before = _position(tester).pixels;
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await open(doc);
    expect(_position(tester).pixels, closeTo(before, 2));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await open(doc.copyWith(id: 'another-html'));
    expect(_position(tester).pixels, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('损坏的阅读记录不影响打开文档', (tester) async {
    await SharedPreferencesAsync().setString(
      ReadingProgressService.keyFor('broken'),
      '{bad',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderDetailPage(
          document: ReadingDocument(
            id: 'broken',
            title: '坏记录',
            content: '正文',
            kind: DocumentKind.markdown,
            updatedAt: DateTime(2026),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_position(tester).pixels, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

Finder _verticalScroll() => find
    .descendant(
      of: find.byType(ReaderDetailPage),
      matching: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    )
    .first;

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(_verticalScroll()).position;
