import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/ast.dart' as math_ast;
import 'package:markdown/markdown.dart' as md;
import 'package:moyue_application/core/display/moyue_markdown_style.dart';

const String moyueInlineLatexTag = 'moyue-latex-inline';
const String moyueBlockLatexTag = 'moyue-latex-block';

final MoyueLatexRenderCache moyueLatexRenderCache = MoyueLatexRenderCache();

/// Bounded LRU cache for unmounted parsed TeX templates.
///
/// Markdown builds cheap [_MoyueLazyMath] placeholders for the whole AST.
/// Actual TeX parsing only happens when a formula reaches the viewport, and
/// revisiting an equation reuses parsing, not live keyed render subtrees.
class MoyueLatexRenderCache {
  MoyueLatexRenderCache({this.maximumEntries = 128})
    : assert(maximumEntries > 0);

  final int maximumEntries;
  final LinkedHashMap<_LatexCacheKey, Math> _entries = LinkedHashMap();
  int _parseCount = 0;

  Widget resolve({
    required String expression,
    required bool display,
    required TextStyle style,
    required Color errorColor,
    required String fallbackText,
    required double textScaleFactor,
  }) {
    final key = _LatexCacheKey(
      expression: expression,
      display: display,
      color: style.color?.toARGB32() ?? 0,
      errorColor: errorColor.toARGB32(),
      fontSize: style.fontSize ?? 16,
      fontWeight: style.fontWeight ?? FontWeight.normal,
      textScaleFactor: textScaleFactor,
    );
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return _IsolatedMath(template: cached);
    }

    _parseCount++;
    final parsed = Math.tex(
      expression,
      mathStyle: display ? MathStyle.display : MathStyle.text,
      textStyle: style,
      textScaleFactor: textScaleFactor,
      onErrorFallback: (_) => SelectionContainer.disabled(
        child: Text(
          fallbackText,
          key: const ValueKey('markdown-latex-error'),
          style: style.copyWith(color: errorColor, fontFamily: 'monospace'),
        ),
      ),
    );
    _entries[key] = parsed;
    while (_entries.length > maximumEntries) {
      _entries.remove(_entries.keys.first);
    }
    return _IsolatedMath(template: parsed);
  }

  @visibleForTesting
  int get debugParseCount => _parseCount;

  @visibleForTesting
  int get debugEntryCount => _entries.length;

  @visibleForTesting
  void debugClear() {
    _entries.clear();
    _parseCount = 0;
  }
}

/// flutter_math's AST caches widgets containing GlobalKeys. Each mounted
/// occurrence needs its own row/branch nodes, even for identical source TeX.
class _IsolatedMath extends StatefulWidget {
  const _IsolatedMath({required this.template});

  final Math template;

  @override
  State<_IsolatedMath> createState() => _IsolatedMathState();
}

class _IsolatedMathState extends State<_IsolatedMath> {
  late Math _math = _instantiate();

  Math _instantiate() {
    final template = widget.template;
    final ast = template.ast;
    return Math(
      ast: ast == null
          ? null
          : math_ast.SyntaxTree(
              greenRoot:
                  _copyMathNode(ast.greenRoot) as math_ast.EquationRowNode,
            ),
      parseError: template.parseError,
      mathStyle: template.mathStyle,
      textStyle: template.textStyle,
      textScaleFactor: template.textScaleFactor,
      onErrorFallback: template.onErrorFallback,
    );
  }

  @override
  void didUpdateWidget(covariant _IsolatedMath oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.template, widget.template)) _math = _instantiate();
  }

  @override
  Widget build(BuildContext context) => _math;
}

math_ast.GreenNode _copyMathNode(math_ast.GreenNode node) {
  // Unicode accented symbols can synthesize keyed equation rows when built.
  if (node is math_ast.SymbolNode) {
    return math_ast.SymbolNode(
      symbol: node.symbol,
      variantForm: node.variantForm,
      overrideAtomType: node.overrideAtomType,
      overrideFont: node.overrideFont,
      mode: node.mode,
    );
  }
  // Phantom is classified as a leaf by the package, but owns a hidden row.
  if (node is math_ast.PhantomNode) {
    return math_ast.PhantomNode(
      phantomChild:
          _copyMathNode(node.phantomChild) as math_ast.EquationRowNode,
      zeroWidth: node.zeroWidth,
      zeroHeight: node.zeroHeight,
      zeroDepth: node.zeroDepth,
    );
  }
  // Matrix updateChildren in 0.7.x flattens/slices rows incorrectly and does
  // not accept nullable cells. Copy its public two-dimensional body instead.
  if (node is math_ast.MatrixNode) {
    return node.copyWith(
      body: [
        for (final row in node.body)
          [
            for (final cell in row)
              cell == null
                  ? null
                  : _copyMathNode(cell) as math_ast.EquationRowNode,
          ],
      ],
    );
  }
  if (node is math_ast.EquationArrayNode) {
    return node.copyWith(
      body: [
        for (final row in node.body)
          _copyMathNode(row) as math_ast.EquationRowNode,
      ],
    );
  }
  final children = node.children.map(
    (child) => child == null ? null : _copyMathNode(child),
  );
  // Preserve the covariant child-list types required by updateChildren.
  if (node is math_ast.SlotableNode<math_ast.EquationRowNode>) {
    return node.updateChildren(
      children.cast<math_ast.EquationRowNode>().toList(),
    );
  }
  if (node is math_ast.SlotableNode<math_ast.EquationRowNode?>) {
    return node.updateChildren(
      children.cast<math_ast.EquationRowNode?>().toList(),
    );
  }
  if (node is math_ast.ParentableNode<math_ast.GreenNode>) {
    return node.updateChildren(children.cast<math_ast.GreenNode>().toList());
  }
  // Remaining leaves (spacing/cursor nodes) have no keyed descendants.
  return node;
}

class _LatexCacheKey {
  const _LatexCacheKey({
    required this.expression,
    required this.display,
    required this.color,
    required this.errorColor,
    required this.fontSize,
    required this.fontWeight,
    required this.textScaleFactor,
  });

  final String expression;
  final bool display;
  final int color;
  final int errorColor;
  final double fontSize;
  final FontWeight fontWeight;
  final double textScaleFactor;

  @override
  bool operator ==(Object other) =>
      other is _LatexCacheKey &&
      expression == other.expression &&
      display == other.display &&
      color == other.color &&
      errorColor == other.errorColor &&
      fontSize == other.fontSize &&
      fontWeight == other.fontWeight &&
      textScaleFactor == other.textScaleFactor;

  @override
  int get hashCode => Object.hash(
    expression,
    display,
    color,
    errorColor,
    fontSize,
    fontWeight,
    textScaleFactor,
  );
}

class _MoyueLazyMath extends StatefulWidget {
  const _MoyueLazyMath({
    required this.expression,
    required this.display,
    required this.style,
    required this.errorColor,
    required this.fallbackText,
  });

  final String expression;
  final bool display;
  final TextStyle style;
  final Color errorColor;
  final String fallbackText;

  @override
  State<_MoyueLazyMath> createState() => _MoyueLazyMathState();
}

class _MoyueLazyMathState extends State<_MoyueLazyMath> {
  static const double _prefetchExtent = 72;

  ScrollPosition? _position;
  bool _activated = false;
  bool _checkScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindPosition(Scrollable.maybeOf(context, axis: Axis.vertical)?.position);
    _scheduleVisibilityCheck();
  }

  @override
  void didUpdateWidget(covariant _MoyueLazyMath oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expression != widget.expression ||
        oldWidget.display != widget.display ||
        oldWidget.style != widget.style ||
        oldWidget.errorColor != widget.errorColor) {
      _activated = false;
      _scheduleVisibilityCheck();
    }
  }

  void _bindPosition(ScrollPosition? next) {
    if (identical(_position, next)) return;
    _position?.removeListener(_handleViewportChange);
    _position?.isScrollingNotifier.removeListener(_handleViewportChange);
    _position = next;
    _position?.addListener(_handleViewportChange);
    _position?.isScrollingNotifier.addListener(_handleViewportChange);
  }

  void _handleViewportChange() => _scheduleVisibilityCheck();

  void _scheduleVisibilityCheck() {
    if (_activated || _checkScheduled || !mounted) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (mounted) _checkVisibility();
    });
  }

  void _checkVisibility() {
    if (_activated) return;
    final scrollable = Scrollable.maybeOf(context, axis: Axis.vertical);
    if (scrollable == null) {
      _activate();
      return;
    }
    _bindPosition(scrollable.position);

    final target = context.findRenderObject();
    final viewport = scrollable.context.findRenderObject();
    if (target is! RenderBox ||
        viewport is! RenderBox ||
        !target.attached ||
        !viewport.attached ||
        !target.hasSize ||
        !viewport.hasSize) {
      _scheduleVisibilityCheck();
      return;
    }

    final targetRect = target.localToGlobal(Offset.zero) & target.size;
    final viewportRect = viewport.localToGlobal(Offset.zero) & viewport.size;
    if (!targetRect.overlaps(viewportRect.inflate(_prefetchExtent))) return;

    // Avoid expensive TeX parsing while a fast fling is competing for frames.
    // isScrollingNotifier schedules another check as soon as scrolling settles.
    if (Scrollable.recommendDeferredLoadingForContext(context) &&
        scrollable.position.isScrollingNotifier.value) {
      return;
    }
    _activate();
  }

  void _activate() {
    if (_activated || !mounted) return;
    setState(() => _activated = true);
  }

  Widget _buildPlaceholder() {
    final fontSize = widget.style.fontSize ?? 16;
    final estimatedWidth = math.min(
      widget.display ? 320.0 : 180.0,
      math.max(fontSize * 1.5, widget.expression.length * fontSize * 0.46),
    );
    return SizedBox(
      key: const ValueKey('markdown-latex-placeholder'),
      width: estimatedWidth,
      height: fontSize * (widget.display ? 1.75 : 1.3),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Off-screen export/share render trees have no vertical Scrollable and must
    // render eagerly; the document reader always takes the lazy branch.
    if (!_activated &&
        Scrollable.maybeOf(context, axis: Axis.vertical) != null) {
      _scheduleVisibilityCheck();
      return _buildPlaceholder();
    }
    return RepaintBoundary(
      child: moyueLatexRenderCache.resolve(
        expression: widget.expression,
        display: widget.display,
        style: widget.style,
        errorColor: widget.errorColor,
        fallbackText: widget.fallbackText,
        textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
      ),
    );
  }

  @override
  void dispose() {
    _position?.removeListener(_handleViewportChange);
    _position?.isScrollingNotifier.removeListener(_handleViewportChange);
    super.dispose();
  }
}

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
          child: _MoyueLazyMath(
            expression: expression,
            display: display,
            style: formulaStyle,
            errorColor: palette.mutedForeground,
            fallbackText: fallbackText,
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

    // Keep the diagnostic key local to this formula. MarkdownBody inserts
    // builder results as siblings in one Column, including repeated formulas.
    return SizedBox(
      width: double.infinity,
      child: Container(
        key: const ValueKey('markdown-latex-block'),
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
      ),
    );
  }
}
