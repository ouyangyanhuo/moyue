import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:moyue_application/features/reader/native_html_view.dart';
import 'package:moyue_application/features/reader/reader_detail_page.dart';
import 'package:moyue_application/features/reader/reader_overlay_tone_sampler.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/native_html_preprocessor.dart';
import 'package:moyue_application/services/package_archive_codec.dart';

Uint8List zip(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile.string(entry.key, entry.value));
  }
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  test('压缩包后台编解码保留中文路径、字节及内容哈希', () async {
    final files = {
      '目录/正文.md': Uint8List.fromList(utf8.encode('# 正文')),
      '目录/样式.css': Uint8List.fromList(utf8.encode('p { color: red }')),
    };
    final decoded = await PackageArchiveCodec.decode(
      await PackageArchiveCodec.encode(files),
    );
    expect(decoded.files, files);
    for (final entry in files.entries) {
      expect(decoded.hashes[entry.key], sha256.convert(entry.value).toString());
    }
  });

  test('解压前拒绝不安全路径、重复路径和不支持的类型', () async {
    for (final name in [
      '../escape.md',
      '/escape.md',
      'C:/escape.md',
      'a.exe',
      'bare',
    ]) {
      await expectLater(
        PackageArchiveCodec.decode(zip({'good.md': 'ok', name: 'bad'})),
        throwsFormatException,
      );
    }
    await expectLater(
      PackageArchiveCodec.decode(zip({'a.md': 'one', './a.md': 'two'})),
      throwsFormatException,
    );
  });

  test('压缩包同时限制输入大小、文件数、单文件及总解压大小', () async {
    final bytes = zip({'a.md': 'a' * 4000, 'b.md': 'b' * 4000});
    for (final limits in const [
      PackageArchiveLimits(compressedBytes: 10),
      PackageArchiveLimits(entries: 1),
      PackageArchiveLimits(fileBytes: 1000),
      PackageArchiveLimits(totalBytes: 5000),
    ]) {
      await expectLater(
        PackageArchiveCodec.decode(bytes, limits: limits),
        throwsFormatException,
      );
    }
  });

  test('CRC 损坏不能被当作正常文档导入', () async {
    final bytes = zip({'a.md': 'first', 'b.md': 'second'});
    // Corrupt the central-directory checksum without altering compressed data.
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i + 46 < bytes.length; i++) {
      if (data.getUint32(i, Endian.little) == 0x02014b50) {
        data.setUint32(i + 16, 0, Endian.little);
        break;
      }
    }
    await expectLater(PackageArchiveCodec.decode(bytes), throwsFormatException);
  });

  test('导出同样限制输出大小，避免生成不能再次导入的包', () async {
    final files = {
      'a.md': Uint8List.fromList(utf8.encode('a' * 4000)),
      'b.md': Uint8List.fromList(utf8.encode('b' * 4000)),
    };
    for (final limits in const [
      PackageArchiveLimits(compressedBytes: 10),
      PackageArchiveLimits(entries: 1),
      PackageArchiveLimits(fileBytes: 1000),
      PackageArchiveLimits(totalBytes: 5000),
    ]) {
      await expectLater(
        PackageArchiveCodec.encode(files, limits: limits),
        throwsFormatException,
      );
    }
  });

  test('伪造解压大小也会在实际输出超限时停止', () async {
    final bytes = zip({'a.md': 'a' * 16000, 'b.md': 'b' * 16000});
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i + 30 < bytes.length; i++) {
      final signature = data.getUint32(i, Endian.little);
      if (signature == 0x02014b50) data.setUint32(i + 24, 1, Endian.little);
      if (signature == 0x04034b50) data.setUint32(i + 22, 1, Endian.little);
      if (signature == 0x08074b50) data.setUint32(i + 12, 1, Endian.little);
    }
    await expectLater(
      PackageArchiveCodec.decode(
        bytes,
        limits: const PackageArchiveLimits(fileBytes: 500),
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'reason',
          contains('大小超过限制'),
        ),
      ),
    );
  });

  test('大 HTML 后台处理保留 CSS、章节与原始锚点', () async {
    final result = await NativeHtmlPreprocessor.prepareDocument(
      data:
          '<link rel="stylesheet" href="style.css"><article id="root">'
          '${List.generate(80, (i) => '<section><h2 id="section-$i">第$i章</h2><p>${'正文内容' * 120}</p></section>').join()}'
          '</article>',
      viewportWidth: 400,
      resourceLoader: (_) async =>
          Uint8List.fromList(utf8.encode('p {color: #123456}')),
    );
    expect(result.sections, hasLength(80));
    expect(result.headingSections[79], 79);
    expect(result.anchorSections['section-79'], 79);
    expect(result.anchorSections['root'], 0);
    expect(result.sections.last.html, contains('#123456'));
  });

  test('复杂网格布局保持原子块，不强制拆散', () async {
    final result = await NativeHtmlPreprocessor.prepareDocument(
      data: '<main style="display:grid;grid-template-columns:1fr 1fr"><p>a</p><p>b</p><p>c</p></main>',
      viewportWidth: 400,
    );
    expect(result.sections, hasLength(1));
  });

  test('滚动取色按距离与速度限频，停止后可重置', () {
    final policy = ReaderToneSamplingPolicy();
    bool scroll(double offset, int ms) =>
        policy.onScroll(offset, Duration(milliseconds: ms));
    expect(scroll(0, 0), isFalse);
    expect(scroll(5, 200), isFalse);
    expect(scroll(25, 250), isTrue);
    expect(scroll(45, 500), isFalse);
    expect(scroll(60, 600), isTrue);
    expect(scroll(400, 780), isFalse); // Fast fling: wait 360 ms.
    expect(scroll(800, 960), isTrue);
    policy.reset();
    expect(scroll(810, 1200), isFalse);
  });

  testWidgets('HTML 按需展开目录目标、已阅章节常驻，且全选可复制末尾', (tester) async {
    String? copied;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final key = GlobalKey<NativeHtmlViewState>();
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scroll,
            child: NativeHtmlView(
              key: key,
              data: List.generate(
                50,
                (i) =>
                    '<section><h2>Chapter $i</h2><p>${'Text for reading. ' * 12}</p></section>',
              ).join(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initial = find.byType(HtmlWidget).evaluate().length;
    expect(initial, lessThan(50));
    final jump = key.currentState!.scrollToHeading(49);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(await jump, isTrue);
    expect(find.text('Chapter 49', findRichText: true), findsOneWidget);
    final visited = find.byType(HtmlWidget).evaluate().length;
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(
      find.byType(HtmlWidget).evaluate().length,
      greaterThanOrEqualTo(visited),
    );

    final areaFinder = find.byType(SelectionArea).first;
    final area = tester.widget<SelectionArea>(areaFinder);
    final region = tester
        .state<SelectionAreaState>(areaFinder)
        .selectableRegion;
    final menu = area.contextMenuBuilder!(
      tester.element(areaFinder),
      region,
    ) as AdaptiveTextSelectionToolbar;
    menu.buttonItems!
        .firstWhere((i) => i.type == ContextMenuButtonType.selectAll)
        .onPressed!();
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.byType(HtmlWidget), findsNWidgets(50));
    region.contextMenuButtonItems
        .firstWhere((i) => i.type == ContextMenuButtonType.copy)
        .onPressed!();
    await tester.pump();
    expect(copied, contains('Chapter 0'));
    expect(copied, contains('Chapter 49'));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('打开目录或提示消息不重建 Markdown 正文', (tester) async {
    for (final content in ['# Heading\n\nText', 'No headings']) {
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderDetailPage(
            key: ValueKey(content),
            document: ReadingDocument(
              id: content,
              title: 'Test',
              content: content,
              kind: DocumentKind.markdown,
              updatedAt: DateTime(2026),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final markdown = tester.widget<Markdown>(find.byType(Markdown));
      await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
      await tester.pumpAndSettle();
      expect(tester.widget<Markdown>(find.byType(Markdown)), same(markdown));
      if (content.startsWith('#')) {
        Navigator.of(tester.element(find.byType(ReaderDetailPage))).pop();
      } else {
        await tester.tapAt(const Offset(400, 300));
      }
      await tester.pumpAndSettle();
      expect(tester.widget<Markdown>(find.byType(Markdown)), same(markdown));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    }
  });
}
