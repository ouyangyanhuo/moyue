import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/display/moyue_glass_style.dart';
import 'package:moyue_application/features/reader/reader_detail_page.dart';
import 'package:moyue_application/features/reader/webview_html_view.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/widgets/floating_document_header.dart';

void main() {
  testWidgets('共享玻璃配方只为缺失纹理样本提供页面底色', (tester) async {
    late LiquidGlassSettings settings;
    late Color surface;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorSchemeSeed: Colors.indigo),
        home: Builder(
          builder: (context) {
            surface = Theme.of(context).colorScheme.surface;
            settings = moyueGlassSettings(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(settings.glassColor.a, 0);
    expect(settings.blur, 5);
    expect(settings.platformViewFallbackColor, surface);
  });

  test('Android WebView 禁用独立 Surface 合成', () {
    expect(moyueWebViewDisplayWithHybridComposition, isFalse);
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(
      manifest,
      isNot(contains('io.flutter.embedding.android.EnableHcpp')),
    );
  });

  testWidgets('WebView 与原生阅读器复用同一 premium 玻璃组件树', (tester) async {
    final display = MoyueDisplayPreferences()..setHtmlWebViewEnabled(true);
    addTearDown(display.dispose);
    final webDocument = ReadingDocument(
      id: 'premium-webview-html',
      title: '网页玻璃测试',
      content: '<h1>网页正文</h1>',
      kind: DocumentKind.html,
      updatedAt: DateTime(2026),
    );

    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: MaterialApp(home: ReaderDetailPage(document: webDocument)),
      ),
    );
    await tester.pump();

    expect(find.byType(WebViewHtmlView), findsOneWidget);
    final webButtons = tester
        .widgetList<GlassButton>(find.byType(GlassButton))
        .toList(growable: false);
    final webTitle = tester.widget<GlassContainer>(
      find.descendant(
        of: find.byType(FloatingDocumentHeader),
        matching: find.byType(GlassContainer),
      ),
    );
    expect(webButtons, hasLength(4));
    expect(
      webButtons.map((button) => button.quality),
      everyElement(GlassQuality.premium),
    );
    expect(
      webButtons.map((button) => button.platformViewBackdrop),
      everyElement(isFalse),
    );
    expect(webTitle.quality, GlassQuality.premium);
    expect(webTitle.platformViewBackdrop, isFalse);

    final webHeaderSignatures = _headerSignatures(tester);
    final webTitleSignature = _titleSignature(webTitle);

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderDetailPage(
          document: ReadingDocument(
            id: 'premium-markdown',
            title: '原生玻璃测试',
            content: '# 正文',
            kind: DocumentKind.markdown,
            updatedAt: DateTime(2026),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_headerSignatures(tester), webHeaderSignatures);
    final nativeTitle = tester.widget<GlassContainer>(
      find.descendant(
        of: find.byType(FloatingDocumentHeader),
        matching: find.byType(GlassContainer),
      ),
    );
    expect(_titleSignature(nativeTitle), webTitleSignature);
  });
}

List<Object> _headerSignatures(WidgetTester tester) => tester
    .widgetList<GlassButton>(
      find.descendant(
        of: find.byType(FloatingDocumentHeader),
        matching: find.byType(GlassButton),
      ),
    )
    .map(
      (button) => (
        button.quality,
        button.useOwnLayer,
        button.platformViewBackdrop,
        button.settings?.blur,
        button.settings?.thickness,
        button.settings?.fresnelStrength,
        button.settings?.platformViewFallbackColor,
      ),
    )
    .toList(growable: false);

Object _titleSignature(GlassContainer title) => (
  title.quality,
  title.useOwnLayer,
  title.platformViewBackdrop,
  title.settings?.blur,
  title.settings?.thickness,
  title.settings?.fresnelStrength,
  title.settings?.platformViewFallbackColor,
);
