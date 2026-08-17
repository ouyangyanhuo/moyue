import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/features/reader/native_html_view.dart';

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

    expect(find.text('原生 HTML'), findsOneWidget);
    expect(find.textContaining('支持'), findsOneWidget);
    expect(find.byType(Text), findsNWidgets(2));
  });
}
