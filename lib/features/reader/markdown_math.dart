import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:moyue_application/core/display/moyue_markdown_style.dart';

const String moyueInlineLatexTag = 'moyue-latex-inline';
const String moyueBlockLatexTag = 'moyue-latex-block';

List<md.BlockSyntax> buildMoyueMarkdownBlockSyntaxes() => <md.BlockSyntax>[
  MoyueLatexBlockSyntax(),
];

List<md.InlineSyntax> buildMoyueMarkdownInlineSyntaxes() => <md.InlineSyntax>[
  MoyueBracketInlineLatexSyntax(),
  MoyueDollarInlineLatexSyntax(),
];

Map<String, MarkdownElementBuilder> buildMoyueMarkdownMathBuilders() =>
    <String, MarkdownElementBuilder>{
      moyueInlineLatexTag: MoyueLatexBuilder(display: false),
      moyueBlockLatexTag: MoyueLatexBuilder(display: true),
    };

/// Parses standalone `$$ ... $$` and `\[ ... \]` display equations.
/// Both one-line and multiline forms are accepted.
class MoyueLatexBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\s*(?:\$\$|\\\[)');

  @override
  md.Node parse(md.BlockParser parser) {
    final firstLine = parser.current.content;
    final leadingTrimmed = firstLine.trimLeft();
    final usesDollars = leadingTrimmed.startsWith(r'$$');
    final opening = usesDollars ? r'$$' : r'\[';
    final closing = usesDollars ? r'$$' : r'\]';
    final expression = StringBuffer();
    var remainder = leadingTrimmed.substring(opening.length);

    while (true) {
      final closeIndex = remainder.lastIndexOf(closing);
      final hasClosingDelimiter =
          closeIndex >= 0 &&
          remainder.substring(closeIndex + closing.length).trim().isEmpty;
      if (hasClosingDelimiter) {
        expression.write(remainder.substring(0, closeIndex));
        parser.advance();
        break;
      }

      if (remainder.isNotEmpty) expression.writeln(remainder);
      parser.advance();
      if (parser.isDone) break;
      remainder = parser.current.content;
    }

    return md.Element.text(moyueBlockLatexTag, expression.toString().trim());
  }
}

/// Parses `$ ... $` without treating escaped dollars or `$$` as inline math.
class MoyueDollarInlineLatexSyntax extends md.InlineSyntax {
  MoyueDollarInlineLatexSyntax()
    : super(
        r'(?<![\\$])\$(?!\$|\s)((?:\\.|[^$\n])*?[^\s$])\$(?!\$)',
        startCharacter: 0x24,
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text(moyueInlineLatexTag, match.group(1)!));
    return true;
  }
}

/// Parses the CommonMark-friendly TeX form `\( ... \)`.
class MoyueBracketInlineLatexSyntax extends md.InlineSyntax {
  MoyueBracketInlineLatexSyntax()
    : super(r'\\\((.+?)\\\)', startCharacter: 0x5C);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text(moyueInlineLatexTag, match.group(1)!));
    return true;
  }
}

class MoyueLatexBuilder extends MarkdownElementBuilder {
  MoyueLatexBuilder({required this.display});

  final bool display;

  @override
  bool isBlockElement() => display;

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) => null;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final expression = element.textContent.trim();
    final palette = moyueMarkdownPaletteOf(context);
    final inheritedStyle =
        parentStyle ??
        preferredStyle ??
        Theme.of(context).textTheme.bodyLarge ??
        const TextStyle(fontSize: 16);
    final formulaStyle = inheritedStyle.copyWith(
      color: palette.foreground,
      fontSize: display
          ? (inheritedStyle.fontSize ?? 16) * 1.06
          : inheritedStyle.fontSize,
      height: 1.25,
    );
    final fallbackText = display
        ? r'$$' + expression + r'$$'
        : r'$' + expression + r'$';
    final formula = Stack(
      alignment: Alignment.center,
      children: [
        Semantics(
          label: 'LaTeX: $expression',
          child: Math.tex(
            expression,
            mathStyle: display ? MathStyle.display : MathStyle.text,
            textStyle: formulaStyle,
            onErrorFallback: (_) => SelectionContainer.disabled(
              child: Text(
                fallbackText,
                key: const ValueKey('markdown-latex-error'),
                style: formulaStyle.copyWith(
                  color: palette.mutedForeground,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
        // WidgetSpan content has no plain-text representation in Flutter's
        // selection system. This zero-opacity, tiny text keeps the original
        // TeX expression in cross-block selections and clipboard output while
        // leaving the rendered formula's geometry and visuals untouched.
        ExcludeSemantics(
          child: Opacity(
            opacity: 0,
            child: Text(
              fallbackText,
              style: formulaStyle.copyWith(fontSize: 1, height: 1),
            ),
          ),
        ),
      ],
    );

    if (!display) {
      return Text.rich(
        TextSpan(
          children: <InlineSpan>[
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: KeyedSubtree(
                key: const ValueKey('markdown-latex-inline'),
                child: formula,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('markdown-latex-block'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: palette.inlineCodeSurface.withValues(alpha: 0.58),
        border: Border.all(color: palette.outline.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Center(child: formula),
          ),
        ),
      ),
    );
  }
}
