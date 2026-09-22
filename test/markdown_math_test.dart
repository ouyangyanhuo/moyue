import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/features/reader/markdown_math.dart';
import 'package:moyue_application/features/reader/reader_detail_page.dart';
import 'package:moyue_application/models/reading_document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Markdown LaTeX 语法识别行内与块级公式', () {
    final nodes =
        md.Document(
          extensionSet: md.ExtensionSet.gitHubWeb,
          blockSyntaxes: buildMoyueMarkdownBlockSyntaxes(),
          inlineSyntaxes: buildMoyueMarkdownInlineSyntaxes(),
        ).parse(r'''
行内公式 $E = mc^2$ 与 \(a^2+b^2=c^2\)。

$$
\frac{-b \pm \sqrt{b^2-4ac}}{2a}
$$

\[
\int_0^1 x^2\,dx
\]
''');

    final formulas = <md.Element>[];
    void collect(md.Node node) {
      if (node case final md.Element element) {
        if (element.tag == moyueInlineLatexTag ||
            element.tag == moyueBlockLatexTag) {
          formulas.add(element);
        }
        for (final child in element.children ?? const <md.Node>[]) {
          collect(child);
        }
      }
    }

    for (final node in nodes) {
      collect(node);
    }
    expect(
      formulas.where((formula) => formula.tag == moyueInlineLatexTag),
      hasLength(2),
    );
    expect(
      formulas.where((formula) => formula.tag == moyueBlockLatexTag),
      hasLength(2),
    );
    expect(
      formulas.map((formula) => formula.textContent),
      contains(r'\frac{-b \pm \sqrt{b^2-4ac}}{2a}'),
    );
  });

  test('LaTeX 解析结果使用有界 LRU 缓存', () {
    final cache = MoyueLatexRenderCache(maximumEntries: 2);
    const style = TextStyle(fontSize: 16, color: Colors.black);
    Widget resolve(String expression) => cache.resolve(
      expression: expression,
      display: false,
      style: style,
      errorColor: Colors.grey,
      fallbackText: '\$$expression\$',
      textScaleFactor: 1,
    );

    final first = resolve('a+b');
    final reused = resolve('a+b');
    expect(identical(first, reused), isTrue);
    expect(cache.debugParseCount, 1);

    resolve('c+d');
    resolve('e+f');
    expect(cache.debugEntryCount, 2);
    expect(cache.debugParseCount, 3);
  });

  testWidgets('Markdown 阅读器原生渲染公式', (tester) async {
    final document = ReadingDocument(
      id: 'latex-reader',
      title: '公式.md',
      content:
          r'行内 $E=mc^2$'
          '\n\n'
          r'$$\frac{a}{b}$$',
      kind: DocumentKind.markdown,
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(home: ReaderDetailPage(document: document)),
    );
    await tester.pump();

    expect(find.byType(Math), findsNWidgets(2));
    expect(find.byKey(const ValueKey('markdown-latex-inline')), findsOneWidget);
    expect(find.byKey(const ValueKey('markdown-latex-block')), findsOneWidget);
    expect(find.byKey(const ValueKey('markdown-latex-error')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('长公式文档仅解析视口附近内容', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    moyueLatexRenderCache.debugClear();
    addTearDown(moyueLatexRenderCache.debugClear);
    final document = ReadingDocument(
      id: 'latex-performance',
      title: '长公式.md',
      content: List<String>.generate(
        100,
        (index) => '\$\$\nx_{$index}=\\frac{$index}{${index + 1}}\n\$\$',
      ).join('\n\n'),
      kind: DocumentKind.markdown,
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(home: ReaderDetailPage(document: document)),
    );
    await tester.pump();

    final initialParseCount = moyueLatexRenderCache.debugParseCount;
    expect(initialParseCount, greaterThan(0));
    expect(initialParseCount, lessThan(20));
    expect(
      find.byKey(
        const ValueKey('markdown-latex-placeholder'),
        skipOffstage: false,
      ),
      findsWidgets,
    );

    await tester.drag(find.byType(Markdown), const Offset(0, -2200));
    await tester.pumpAndSettle();

    expect(
      moyueLatexRenderCache.debugParseCount,
      greaterThan(initialParseCount),
    );
    expect(moyueLatexRenderCache.debugParseCount, lessThan(100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Markdown 可跨段全选并复制', (tester) async {
    String? copiedText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    final document = ReadingDocument(
      id: 'select-reader',
      title: '选择.md',
      content:
          r'# 跨段选择'
          '\n\n'
          r'第一段正文 $E=mc^2$。'
          '\n\n'
          r'$$\frac{a}{b}$$'
          '\n\n第二段正文。',
      kind: DocumentKind.markdown,
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(home: ReaderDetailPage(document: document)),
    );
    await tester.pump();

    final markdown = tester.widget<Markdown>(find.byType(Markdown));
    expect(markdown.selectable, isFalse);
    final selectionArea = tester.state<SelectionAreaState>(
      find.byKey(const ValueKey('markdown-document-selection-area')),
    );
    selectionArea.selectableRegion.contextMenuButtonItems
        .firstWhere((item) => item.type == ContextMenuButtonType.selectAll)
        .onPressed!();
    await tester.pump();
    selectionArea.selectableRegion.contextMenuButtonItems
        .firstWhere((item) => item.type == ContextMenuButtonType.copy)
        .onPressed!();
    await tester.pump();

    expect(copiedText, contains('跨段选择'));
    expect(copiedText, contains('第一段正文'));
    expect(copiedText, contains('E=mc^2'));
    expect(copiedText, contains(r'\frac{a}{b}'));
    expect(copiedText, contains('第二段正文。'));
  });

  testWidgets('整体渲染可选择并复制尚未滚动到的全文', (tester) async {
    String? copiedText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final display = MoyueDisplayPreferences()
      ..setMarkdownRenderingMode(MarkdownRenderingMode.wholeDocument);
    addTearDown(display.dispose);
    final document = ReadingDocument(
      id: 'whole-document-selection',
      title: '全文选择.md',
      content: [
        '# 全文选择',
        ...List<String>.generate(120, (index) => '第 $index 段正文。'),
        '全文末尾标记。',
      ].join('\n\n'),
      kind: DocumentKind.markdown,
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: MaterialApp(home: ReaderDetailPage(document: document)),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('markdown-whole-document-renderer')),
      findsOneWidget,
    );
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.byType(Markdown), findsNothing);
    final selectionArea = tester.state<SelectionAreaState>(
      find.byKey(const ValueKey('markdown-document-selection-area')),
    );
    selectionArea.selectableRegion.contextMenuButtonItems
        .firstWhere((item) => item.type == ContextMenuButtonType.selectAll)
        .onPressed!();
    await tester.pump();
    selectionArea.selectableRegion.contextMenuButtonItems
        .firstWhere((item) => item.type == ContextMenuButtonType.copy)
        .onPressed!();
    await tester.pump();

    expect(copiedText, contains('全文选择'));
    expect(copiedText, contains('第 119 段正文。'));
    expect(copiedText, contains('全文末尾标记。'));
  });
}
