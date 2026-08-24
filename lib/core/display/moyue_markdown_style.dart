import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:highlighting/highlighting.dart' as syntax;
import 'package:highlighting/languages/all.dart' as syntax_languages;
import 'package:markdown/markdown.dart' as md;
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/display/moyue_code_theme_registry.dart';
import 'package:moyue_application/core/display/moyue_color_contrast.dart';
import 'package:moyue_application/core/display/moyue_markdown_theme_registry.dart';
import 'package:moyue_application/core/i18n/moyue_i18n.dart';

MoyueMarkdownThemeDefinition moyueMarkdownThemeOf(BuildContext context) {
  final id =
      DisplayPreferencesScope.maybeOf(context)?.markdownThemeId ??
      MoyueMarkdownThemeRegistry.defaultThemeId;
  return MoyueMarkdownThemeRegistry.resolve(id);
}

MoyueMarkdownPalette moyueMarkdownPaletteOf(BuildContext context) =>
    moyueMarkdownThemeOf(context).palette(Theme.of(context).colorScheme);

MoyueCodeThemeDefinition moyueCodeThemeOf(BuildContext context) {
  final id =
      DisplayPreferencesScope.maybeOf(context)?.codeThemeId ??
      MoyueCodeThemeRegistry.defaultThemeId;
  return MoyueCodeThemeRegistry.resolve(id);
}

Map<String, TextStyle> moyueCodePaletteOf(BuildContext context) =>
    moyueCodeThemeOf(context).palette(Theme.of(context).brightness);

@immutable
class MoyueCodeBlockPalette {
  const MoyueCodeBlockPalette({
    required this.background,
    required this.headerBackground,
    required this.foreground,
    required this.mutedForeground,
    required this.outline,
    required this.accent,
    required this.syntaxStyles,
  });

  final Color background;
  final Color headerBackground;
  final Color foreground;
  final Color mutedForeground;
  final Color outline;
  final Color accent;
  final Map<String, TextStyle> syntaxStyles;
}

/// Converts arbitrary highlight.js palettes into a stable, readable code-card
/// palette. Every token is checked against its effective background, so a
/// side-loaded theme cannot render invisible comments, strings, or keys.
MoyueCodeBlockPalette normalizeMoyueCodeBlockPalette({
  required Map<String, TextStyle> source,
  required MoyueMarkdownPalette reader,
}) {
  final root = source['root'];
  final readerIsDark =
      ThemeData.estimateBrightnessForColor(reader.surface) == Brightness.dark;
  final rawBackground = moyueOpaqueOver(
    root?.backgroundColor ??
        (readerIsDark ? const Color(0xFF15171B) : const Color(0xFFF4F5F7)),
    reader.surface,
  );
  final codeIsDark =
      ThemeData.estimateBrightnessForColor(rawBackground) == Brightness.dark;
  final background = Color.lerp(
    reader.surface,
    rawBackground,
    readerIsDark == codeIsDark ? 0.92 : 0.985,
  )!;
  final fallbackForeground = readerIsDark
      ? const Color(0xFFF4F5F7)
      : const Color(0xFF20242A);
  final foreground = moyueEnsureContrast(
    root?.color ?? fallbackForeground,
    background,
    minimumRatio: 7,
  );
  final normalizedStyles = <String, TextStyle>{};
  for (final entry in source.entries) {
    final style = entry.value;
    final tokenBackground = style.backgroundColor == null
        ? background
        : moyueOpaqueOver(style.backgroundColor!, background);
    normalizedStyles[entry.key] = style.copyWith(
      color: moyueEnsureContrast(
        style.color ?? foreground,
        tokenBackground,
        minimumRatio: 4.5,
      ),
      backgroundColor: style.backgroundColor == null ? null : tokenBackground,
    );
  }
  normalizedStyles['root'] = (root ?? const TextStyle()).copyWith(
    color: foreground,
    backgroundColor: background,
  );
  final headerBackground = Color.alphaBlend(
    foreground.withValues(alpha: readerIsDark ? 0.055 : 0.04),
    background,
  );
  return MoyueCodeBlockPalette(
    background: background,
    headerBackground: headerBackground,
    foreground: foreground,
    mutedForeground: moyueEnsureContrast(
      Color.lerp(foreground, headerBackground, 0.46)!,
      headerBackground,
      minimumRatio: 4.5,
    ),
    outline: Color.alphaBlend(
      foreground.withValues(alpha: readerIsDark ? 0.15 : 0.11),
      background,
    ),
    accent: moyueEnsureContrast(
      reader.accent,
      headerBackground,
      minimumRatio: 3,
    ),
    syntaxStyles: Map.unmodifiable(normalizedStyles),
  );
}

/// Shared native Markdown presentation used by reading, editor preview, and
/// full-document image export. Themes change color only; typographic rhythm is
/// deliberately stable between every palette.
MarkdownStyleSheet buildMoyueMarkdownStyleSheet(BuildContext context) {
  final theme = Theme.of(context);
  final palette = moyueMarkdownPaletteOf(context);
  final body = theme.textTheme.bodyLarge!.copyWith(
    height: 1.76,
    color: palette.foreground,
    letterSpacing: 0.05,
  );
  final secondaryBody = theme.textTheme.bodyMedium!.copyWith(
    height: 1.68,
    color: palette.foreground,
  );
  final readerIsDark =
      ThemeData.estimateBrightnessForColor(palette.surface) == Brightness.dark;

  return MarkdownStyleSheet(
    p: body,
    pPadding: const EdgeInsets.only(bottom: 1),
    blockSpacing: 16,
    h1: theme.textTheme.headlineLarge?.copyWith(
      color: palette.heading,
      height: 1.2,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.65,
    ),
    h1Padding: const EdgeInsets.only(top: 22, bottom: 9),
    h2: theme.textTheme.headlineMedium?.copyWith(
      color: palette.heading,
      height: 1.27,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.38,
    ),
    h2Padding: const EdgeInsets.only(top: 18, bottom: 8),
    h3: theme.textTheme.titleLarge?.copyWith(
      color: palette.heading,
      height: 1.34,
      fontWeight: FontWeight.w700,
    ),
    h3Padding: const EdgeInsets.only(top: 14, bottom: 6),
    h4: theme.textTheme.titleMedium?.copyWith(
      color: palette.heading,
      height: 1.4,
      fontWeight: FontWeight.w700,
    ),
    h4Padding: const EdgeInsets.only(top: 11, bottom: 5),
    h5: body.copyWith(fontWeight: FontWeight.w700, color: palette.heading),
    h6: body.copyWith(
      fontWeight: FontWeight.w600,
      color: palette.mutedForeground,
    ),
    strong: body.copyWith(fontWeight: FontWeight.w700, color: palette.heading),
    em: body.copyWith(fontStyle: FontStyle.italic),
    del: body.copyWith(
      decoration: TextDecoration.lineThrough,
      decorationColor: palette.mutedForeground,
    ),
    a: body.copyWith(
      color: palette.link,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: palette.link.withValues(alpha: 0.52),
      decorationThickness: 1.15,
    ),
    blockquote: body.copyWith(color: palette.mutedForeground, height: 1.7),
    blockquotePadding: const EdgeInsets.fromLTRB(18, 14, 17, 14),
    blockquoteDecoration: BoxDecoration(
      color: palette.blockquoteSurface,
      border: Border(left: BorderSide(color: palette.accent, width: 3.5)),
      borderRadius: BorderRadius.circular(13),
    ),
    code: secondaryBody.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const [
        'Noto Sans Mono',
        'JetBrains Mono',
        'Courier New',
      ],
      fontSize: (secondaryBody.fontSize ?? 15) * 0.91,
      height: 1.48,
      fontWeight: FontWeight.w600,
      color: palette.inlineCodeForeground,
      backgroundColor: palette.inlineCodeSurface,
    ),
    // The custom builder owns the complete card, header, clipping and padding.
    codeblockPadding: EdgeInsets.zero,
    codeblockDecoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: readerIsDark ? 0.2 : 0.065),
          blurRadius: 17,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    listIndent: 27,
    listBullet: body.copyWith(
      color: palette.accent,
      fontWeight: FontWeight.w800,
    ),
    listBulletPadding: const EdgeInsets.only(right: 7),
    checkbox: body.copyWith(color: palette.accent),
    tableHead: secondaryBody.copyWith(
      color: palette.heading,
      fontWeight: FontWeight.w700,
    ),
    tableBody: secondaryBody,
    tableHeadAlign: TextAlign.start,
    tablePadding: const EdgeInsets.symmetric(vertical: 9),
    tableBorder: TableBorder.all(color: palette.outline, width: 0.8),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    tableCellsDecoration: BoxDecoration(color: palette.surface),
    tableHeadCellsDecoration: BoxDecoration(color: palette.tableHeaderSurface),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: palette.outline.withValues(alpha: 0.82)),
      ),
    ),
  );
}

MoyueCodeBlockBuilder buildMoyueCodeBlockBuilder(BuildContext context) =>
    MoyueCodeBlockBuilder(
      palette: normalizeMoyueCodeBlockPalette(
        source: moyueCodePaletteOf(context),
        reader: moyueMarkdownPaletteOf(context),
      ),
      selectionColor: Theme.of(context).colorScheme.primary
          .withValues(alpha: 0.28),
    );

class MoyueCodeBlockBuilder extends MarkdownElementBuilder {
  MoyueCodeBlockBuilder({required this.palette, required this.selectionColor});

  final MoyueCodeBlockPalette palette;
  final Color selectionColor;
  String _source = '';
  String _language = 'plaintext';

  @override
  bool isBlockElement() => true;

  @override
  void visitElementBefore(md.Element element) {
    final code = element.children
        ?.whereType<md.Element>()
        .where((child) => child.tag == 'code')
        .firstOrNull;
    final className = code?.attributes['class'] ?? '';
    final match = RegExp(r'(?:language|lang)-([^\s]+)').firstMatch(className);
    _language = _normalizeLanguage(match?.group(1));
    _source = element.textContent.replaceFirst(RegExp(r'\n$'), '');
  }

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) => null;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final source = _source;
    final language = _language;
    _source = '';
    _language = 'plaintext';
    final parserLanguage =
        syntax_languages.builtinLanguages.containsKey(language)
        ? language
        : 'plaintext';
    // flutter_highlighting's own public widget delegates to this singleton.
    // Calling it here keeps syntax spans inside Moyue's SelectionArea.
    // ignore: invalid_use_of_internal_member
    final result = syntax.highlight.highlight(parserLanguage, source, true);
    return MoyueCodeBlock(
      source: source,
      language: language,
      palette: palette,
      selectionColor: selectionColor,
      spans: _convertNodes(result.nodes ?? const []),
    );
  }

  List<TextSpan> _convertNodes(List<syntax.Node> nodes) => [
    for (final node in nodes) _convertNode(node),
  ];

  TextSpan _convertNode(syntax.Node node) => TextSpan(
    text: node.value,
    style: node.className == null ? null : palette.syntaxStyles[node.className],
    children: node.children.isEmpty ? null : _convertNodes(node.children),
  );

  static String _normalizeLanguage(String? language) =>
      switch (language?.toLowerCase()) {
        null || '' => 'plaintext',
        'js' => 'javascript',
        'ts' => 'typescript',
        'sh' || 'shell' => 'bash',
        'yml' => 'yaml',
        'html' => 'xml',
        'kt' => 'kotlin',
        'py' => 'python',
        'rb' => 'ruby',
        'cs' || 'csharp' => 'csharp',
        final value => value,
      };
}

class MoyueCodeBlock extends StatefulWidget {
  const MoyueCodeBlock({
    required this.source,
    required this.language,
    required this.palette,
    required this.selectionColor,
    required this.spans,
    super.key,
  });

  final String source;
  final String language;
  final MoyueCodeBlockPalette palette;
  final Color selectionColor;
  final List<TextSpan> spans;

  @override
  State<MoyueCodeBlock> createState() => _MoyueCodeBlockState();
}

class _MoyueCodeBlockState extends State<MoyueCodeBlock> {
  final ScrollController _horizontalController = ScrollController();
  Timer? _copiedTimer;
  bool _copied = false;

  int get _lineCount => math.max(1, '\n'.allMatches(widget.source).length + 1);

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.source));
    if (!mounted) return;
    _copiedTimer?.cancel();
    setState(() => _copied = true);
    _copiedTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final isDark =
        ThemeData.estimateBrightnessForColor(palette.background) ==
        Brightness.dark;
    return Container(
      key: const ValueKey('moyue-code-block'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.background,
            Color.alphaBlend(
              palette.accent.withValues(alpha: isDark ? 0.025 : 0.018),
              palette.background,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.outline, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          Container(height: 0.8, color: palette.outline),
          _buildCode(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final palette = widget.palette;
    return ColoredBox(
      color: palette.headerBackground,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.only(left: 14, right: 4),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _displayLanguage(context, widget.language),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: palette.foreground,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.22,
                            ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      context.l10n.codeLineCount(_lineCount),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: palette.mutedForeground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: Tooltip(
                  message: _copied
                      ? context.l10n.codeCopied
                      : context.l10n.copyCode,
                  child: Semantics(
                    button: true,
                    label: _copied
                        ? context.l10n.codeCopied
                        : context.l10n.copyCode,
                    child: InkResponse(
                      onTap: _copy,
                      radius: 23,
                      containedInkWell: true,
                      highlightShape: BoxShape.circle,
                      child: SizedBox.square(
                        dimension: 44,
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: moyueMotionDuration(
                              context,
                              const Duration(milliseconds: 150),
                            ),
                            child: Icon(
                              _copied
                                  ? Icons.check_rounded
                                  : Icons.content_copy_rounded,
                              key: ValueKey(_copied),
                              size: 17,
                              color: _copied
                                  ? palette.accent
                                  : palette.mutedForeground,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCode(BuildContext context) {
    final palette = widget.palette;
    final showLineNumbers = _lineCount > 1;
    final lineNumberText = [
      for (var line = 1; line <= _lineCount; line++) '$line',
    ].join('\n');
    final textStyle = TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const [
        'Noto Sans Mono',
        'JetBrains Mono',
        'Courier New',
      ],
      fontSize: 13.2,
      height: 1.62,
      letterSpacing: 0.05,
      color: palette.foreground,
    );
    return LayoutBuilder(
      builder: (context, constraints) => Scrollbar(
        controller: _horizontalController,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 15),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: math.max(0, constraints.maxWidth - 30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showLineNumbers) ...[
                  ExcludeSemantics(
                    child: Text(
                      lineNumberText,
                      textAlign: TextAlign.right,
                      style: textStyle.copyWith(
                        color: palette.mutedForeground,
                        backgroundColor: Colors.transparent,
                        decoration: TextDecoration.none,
                        fontWeight: FontWeight.w400,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 0.8,
                    height: _lineCount * 13.2 * 1.62,
                    color: palette.outline,
                  ),
                  const SizedBox(width: 13),
                ],
                RichText(
                  selectionRegistrar: SelectionContainer.maybeOf(context),
                  selectionColor: widget.selectionColor,
                  softWrap: false,
                  text: TextSpan(
                    style: textStyle,
                    children: widget.spans.isEmpty
                        ? [TextSpan(text: widget.source)]
                        : widget.spans,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _displayLanguage(BuildContext context, String language) =>
      switch (language) {
        'plaintext' => context.l10n.plainTextCode,
        'javascript' => 'JavaScript',
        'typescript' => 'TypeScript',
        'xml' => 'HTML / XML',
        'css' => 'CSS',
        'json' => 'JSON',
        'bash' => 'Shell',
        'dart' => 'Dart',
        'kotlin' => 'Kotlin',
        'swift' => 'Swift',
        'python' => 'Python',
        'ruby' => 'Ruby',
        'csharp' => 'C#',
        'cpp' => 'C++',
        final value => value.toUpperCase(),
      };
}
