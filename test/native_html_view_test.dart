import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:moyue_application/features/reader/native_html_view.dart';
import 'package:moyue_application/services/native_html_preprocessor.dart';
import 'package:moyue_application/services/webview_document_builder.dart';
import 'package:moyue_application/services/text_decoder.dart';
import 'package:path/path.dart' as p;

void main() {
  testWidgets('HTML 由 Flutter 文本和区块组件直接渲染', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NativeHtmlView(
              data: '<h1>原生 HTML</h1><p>支持 <strong>强调</strong> 排版。</p>',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('原生 HTML', findRichText: true), findsOneWidget);
    expect(find.textContaining('支持', findRichText: true), findsOneWidget);
    expect(find.byType(HtmlWidget), findsAtLeastNWidgets(1));
  });

  testWidgets('HTML 会读取包内相对 CSS 并内联到原生渲染树', (tester) async {
    final requested = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NativeHtmlView(
            data: '<link rel="stylesheet" href="styles/site.css"><p>正文</p>',
            resourceLoader: (path) async {
              requested.add(path);
              return Uint8List.fromList('.article { color: red; }'.codeUnits);
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(requested, ['styles/site.css']);
    expect(find.text('正文', findRichText: true), findsOneWidget);
  });

  test('CSS 变量、响应式规则、Grid 和确定性脚本状态会被原生化', () async {
    final prepared = await NativeHtmlPreprocessor.prepare(
      viewportWidth: 390,
      data: '''
        <style>
          :root { --accent: #d1410c; }
          .grid { display:grid; grid-template-columns:repeat(3, 1fr); gap:8px; }
          .grid > div { color:var(--accent); }
          @media (max-width: 820px) {
            .grid { grid-template-columns:1fr; }
          }
        </style>
        <div class="grid"><div>甲</div><div>乙</div></div>
        <script>throw new Error('Flutter 不应执行脚本')</script>
      ''',
    );
    final document = html_parser.parse(prepared);
    final grid = document.querySelector('.grid')!;
    expect(grid.attributes['data-moyue-grid-columns'], '1');
    expect(grid.children.first.attributes['style'], contains('color:#d1410c'));
    expect(document.querySelectorAll('script,style'), isEmpty);
  });

  test('工作区 ahtml.zip 的样式、资源和动态图表均可建立原生映射', () async {
    final files = _loadAhtmlArchive();
    if (files == null) return;
    final html = decodeImportedText(files['im-magneto-x-report.html']!);
    final requested = <String>[];
    final prepared = await NativeHtmlPreprocessor.prepare(
      data: html,
      viewportWidth: 390,
      resourceLoader: (path) async {
        requested.add(path);
        return files[path];
      },
    );
    final document = html_parser.parse(prepared);
    expect(document.querySelectorAll('script,style'), isEmpty);
    expect(
      document.querySelectorAll('[data-moyue-grid-columns]').length,
      greaterThan(10),
    );
    expect(
      document
          .querySelector('.banner')
          ?.attributes['data-moyue-background-image'],
      'im-magneto-header.jpg',
    );
    expect(document.querySelectorAll('#weightList .weight-row'), hasLength(7));
    expect(document.querySelectorAll('#sequence .seq-item'), hasLength(5));
    expect(document.querySelectorAll('#dotGrid .dot'), hasLength(100));
    expect(document.querySelectorAll('[id^="moyue-heading-"]'), isNotEmpty);
    expect(files['im-magneto-header.jpg'], isNotEmpty);
    expect(files['im-magneto-avatar.jpg'], isNotEmpty);
    expect(requested, isEmpty);
  });

  testWidgets('工作区 ahtml.zip 在手机宽度下由原生交互控件稳定渲染', (tester) async {
    final files = _loadAhtmlArchive();
    if (files == null) return;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NativeHtmlView(
              data: decodeImportedText(files['im-magneto-x-report.html']!),
              resourceLoader: (path) async => files[path],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(tester.takeException(), isNull);
    expect(find.byType(SegmentedButton<int>), findsOneWidget);
    expect(find.byType(SegmentedButton<String>), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byType(HtmlWidget), findsAtLeastNWidgets(10));

    tester
        .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
        .onSelectionChanged
        ?.call({30});
    await tester.pump();
    expect(find.text('476'), findsWidgets);

    tester
        .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
        .onSelectionChanged
        ?.call({'negative'});
    await tester.pump();
    expect(find.text('举报'), findsWidgets);
    expect(find.text('-234.0'), findsWidgets);

    tester.widget<Slider>(find.byType(Slider)).onChanged?.call(4);
    await tester.pump();
    expect(find.text('k = 4'), findsWidgets);
    expect(find.text('0.2969'), findsWidgets);
  });

  test('WebView 页面保留 ahtml 脚本并内嵌包内资源', () async {
    final files = _loadAhtmlArchive();
    if (files == null) return;
    final built = await WebViewDocumentBuilder.build(
      html: decodeImportedText(files['im-magneto-x-report.html']!),
      resourceLoader: (path) async => files[path],
      topInset: 96,
      bottomInset: 92,
    );
    final document = html_parser.parse(built);

    expect(document.querySelector('script')?.text, contains('const periods'));
    expect(
      document.querySelector('img')?.attributes['src'],
      startsWith('data:image/jpeg;base64,'),
    );
    expect(
      document.querySelectorAll('style').map((style) => style.text).join(),
      allOf(
        contains('data:image/jpeg;base64,'),
        contains('padding-top: 96.0px'),
        contains('padding-bottom: 92.0px'),
        contains('scrollbar-width: none'),
        contains('::-webkit-scrollbar'),
      ),
    );
  });
}

Map<String, Uint8List>? _loadAhtmlArchive() {
  final file = File(p.join(Directory.current.parent.path, 'ahtml.zip'));
  if (!file.existsSync()) return null;
  final archive = ZipDecoder().decodeBytes(
    file.readAsBytesSync(),
    verify: true,
  );
  return {
    for (final entry in archive.files)
      if (entry.isFile) entry.name: entry.readBytes() ?? Uint8List(0),
  };
}
