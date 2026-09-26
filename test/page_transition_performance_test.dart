import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/core/navigation/moyue_page_route.dart';
import 'package:moyue_application/features/reader/reader_detail_page.dart';
import 'package:moyue_application/features/reader/reader_overlay_tone_sampler.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/widgets/floating_document_header.dart';
import 'package:moyue_application/widgets/scrolling_title.dart';

void main() {
  testWidgets('背景取色仅更新浮动控件，不重建 Markdown 正文', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderDetailPage(
          document: ReadingDocument(
            id: 'tone-rebuild-regression',
            title: 'Document',
            content: '# Heading\n\nText with **formatting**.',
            kind: DocumentKind.markdown,
            updatedAt: DateTime(2026),
          ),
        ),
      ),
    );
    await tester.pump();
    final markdown = tester.widget<Markdown>(find.byType(Markdown));
    final sampler = tester.widget<ReaderOverlayToneSampler>(
      find.byType(ReaderOverlayToneSampler),
    );
    for (final brightness in [Brightness.dark, Brightness.light]) {
      sampler.onChanged(ReaderOverlayTone(top: brightness, bottom: brightness));
      await tester.pump();
      expect(tester.widget<Markdown>(find.byType(Markdown)), same(markdown));
      expect(
        tester
            .widget<FloatingDocumentHeader>(find.byType(FloatingDocumentHeader))
            .foregroundColor,
        brightness == Brightness.dark ? Colors.white : Colors.black,
      );
    }
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('隐藏页面停止滚动标题的 ticker 和等待计时，恢复后继续', (tester) async {
    Widget app(bool enabled) => MaterialApp(
      home: Scaffold(
        body: TickerMode(
          enabled: enabled,
          child: const SizedBox(
            width: 100,
            child: ScrollingTitle(
              'A very long document name that needs to scroll across the page',
              autoScroll: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(true));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 200));
    final controller = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    expect(controller.offset, greaterThan(0));
    await tester.pumpWidget(app(false));
    final stopped = controller.offset;
    await tester.pump(const Duration(seconds: 2));
    expect(controller.offset, stopped);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(app(true));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.offset, greaterThan(stopped));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('路由动画复用页面子树并保留实时渲染配置', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('Home')),
      ),
    );
    var builds = 0;
    final route = MoyueMaterialPageRoute<void>(
      predictiveBackEnabled: true,
      reduceMotion: false,
      inkMode: false,
      allowSnapshotting: false,
      builder: (_) {
        builds++;
        return const Scaffold(body: Text('Reader'));
      },
    );
    navigator.currentState!.push(route);
    await tester.pump();
    final firstBuilds = builds;
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(builds, firstBuilds);
    expect(route.allowSnapshotting, isFalse);
    expect(route.predictiveBackEnabled, isTrue);
    expect(
      find.ancestor(
        of: find.text('Reader'),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
