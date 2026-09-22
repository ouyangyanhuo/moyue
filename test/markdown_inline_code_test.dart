import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/core/display/moyue_markdown_style.dart';

void main() {
  for (final wholeDocument in [false, true]) {
    testWidgets('行内代码紧贴正文并保留原文空格 whole=$wholeDocument', (tester) async {
      late MarkdownStyleSheet styles;
      await tester.pumpWidget(
        MaterialApp(
          // Deliberately give the secondary body tracking so the test detects
          // accidental inheritance from the previous inline-code style.
          theme: ThemeData(
            textTheme: const TextTheme(
              bodyLarge: TextStyle(fontSize: 17),
              bodyMedium: TextStyle(
                fontSize: 15,
                letterSpacing: 2,
                wordSpacing: 4,
              ),
            ),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                styles = buildMoyueMarkdownStyleSheet(context);
                const data = '前`code`后\n\n前 `a b` 后';
                return SelectionArea(
                  child: wholeDocument
                      ? SingleChildScrollView(
                          child: MarkdownBody(data: data, styleSheet: styles),
                        )
                      : Markdown(data: data, styleSheet: styles),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(styles.code!.letterSpacing, 0);
      expect(styles.code!.wordSpacing, 0);
      expect(styles.code!.height, isNull);
      expect(styles.code!.fontSize, closeTo(styles.p!.fontSize! * 0.9, 0.001));
      for (final text in ['前code后', '前 a b 后']) {
        final finder = find.byWidgetPredicate(
          (widget) => widget is RichText && widget.text.toPlainText() == text,
        );
        // The code and adjacent prose must remain one selectable paragraph,
        // not separate Wrap children or padded inline widgets.
        expect(finder, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(finder);
        final firstCode = text.indexOf(text == '前code后' ? 'c' : 'a');
        final previous = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: firstCode - 1, extentOffset: firstCode),
            )
            .single;
        final code = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: firstCode, extentOffset: firstCode + 1),
            )
            .single;
        expect(code.left - previous.right, closeTo(0, 0.01));
        const afterCode = 5;
        final last = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: afterCode - 1, extentOffset: afterCode),
            )
            .single;
        final next = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: afterCode, extentOffset: afterCode + 1),
            )
            .single;
        expect(next.left - last.right, closeTo(0, 0.01));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
