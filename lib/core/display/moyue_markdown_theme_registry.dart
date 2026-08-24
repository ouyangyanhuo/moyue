import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:moyue_application/core/display/moyue_color_contrast.dart';
import 'package:moyue_application/core/i18n/moyue_i18n.dart';

typedef MoyueThemeLabelBuilder = String Function(BuildContext context);
typedef MoyueMarkdownPaletteBuilder = MoyueMarkdownPalette Function(
  ColorScheme colors,
);

class MoyueMarkdownPalette {
  const MoyueMarkdownPalette({
    required this.surface,
    required this.foreground,
    required this.mutedForeground,
    required this.heading,
    required this.link,
    required this.accent,
    required this.blockquoteSurface,
    required this.inlineCodeSurface,
    required this.tableHeaderSurface,
    required this.outline,
    this.inlineCodeForeground,
  });

  final Color surface;
  final Color foreground;
  final Color mutedForeground;
  final Color heading;
  final Color link;
  final Color accent;
  final Color blockquoteSurface;
  final Color inlineCodeSurface;
  final Color tableHeaderSurface;
  final Color outline;
  final Color? inlineCodeForeground;

  /// Applies a final accessibility guard to built-in and side-loaded themes.
  /// Theme authors keep control of hue and surfaces; only colors that would
  /// become difficult to read are moved toward black or white.
  MoyueMarkdownPalette normalized() {
    final page = surface.withValues(alpha: 1);
    final quote = moyueOpaqueOver(blockquoteSurface, page);
    final inlineCode = moyueOpaqueOver(inlineCodeSurface, page);
    final tableHeader = moyueOpaqueOver(tableHeaderSurface, page);
    final readableForeground = moyueEnsureContrastAcross(foreground, [
      page,
    ], minimumRatio: 6.5);
    final readableMuted = moyueEnsureContrastAcross(mutedForeground, [
      page,
      quote,
    ], minimumRatio: 4.5);
    final readableHeading = moyueEnsureContrastAcross(heading, [
      page,
      tableHeader,
    ], minimumRatio: 6.5);
    return MoyueMarkdownPalette(
      surface: page,
      foreground: readableForeground,
      mutedForeground: readableMuted,
      heading: readableHeading,
      link: moyueEnsureContrast(link, page, minimumRatio: 4.5),
      accent: moyueEnsureContrast(accent, page, minimumRatio: 3),
      blockquoteSurface: quote,
      inlineCodeSurface: inlineCode,
      tableHeaderSurface: tableHeader,
      outline: moyueEnsureContrast(outline, page, minimumRatio: 1.6),
      inlineCodeForeground: moyueEnsureContrast(
        inlineCodeForeground ?? readableHeading,
        inlineCode,
        minimumRatio: 4.5,
      ),
    );
  }
}

class MoyueMarkdownThemeDefinition {
  const MoyueMarkdownThemeDefinition({
    required this.id,
    required this.labelBuilder,
    required this.descriptionBuilder,
    required this.paletteBuilder,
  });

  final String id;
  final MoyueThemeLabelBuilder labelBuilder;
  final MoyueThemeLabelBuilder descriptionBuilder;
  final MoyueMarkdownPaletteBuilder paletteBuilder;

  String label(BuildContext context) => labelBuilder(context);
  String description(BuildContext context) => descriptionBuilder(context);
  MoyueMarkdownPalette palette(ColorScheme colors) =>
      paletteBuilder(colors).normalized();
}

/// Independent Markdown color-theme contribution point.
///
/// A future feature package can register a definition during app startup and
/// persist only its stable [MoyueMarkdownThemeDefinition.id]. No settings-page
/// or display-controller enum needs to be edited when another theme is added.
class MoyueMarkdownThemeRegistry {
  MoyueMarkdownThemeRegistry._();

  static const defaultThemeId = 'moyue-adaptive';
  static final Set<String> _builtInIds = <String>{};
  static final LinkedHashMap<String, MoyueMarkdownThemeDefinition> _themes =
      LinkedHashMap<String, MoyueMarkdownThemeDefinition>();

  static List<MoyueMarkdownThemeDefinition> get themes {
    _ensureBuiltIns();
    return List.unmodifiable(_themes.values);
  }

  static void register(
    MoyueMarkdownThemeDefinition theme, {
    bool replace = false,
  }) {
    _ensureBuiltIns();
    if (theme.id.trim().isEmpty) {
      throw ArgumentError.value(theme.id, 'theme.id', 'must not be empty');
    }
    if (!replace && _themes.containsKey(theme.id)) {
      throw StateError('Markdown theme "${theme.id}" is already registered.');
    }
    _themes[theme.id] = theme;
  }

  static bool unregister(String id) {
    _ensureBuiltIns();
    if (_builtInIds.contains(id)) return false;
    return _themes.remove(id) != null;
  }

  static MoyueMarkdownThemeDefinition resolve(String id) {
    _ensureBuiltIns();
    return _themes[id] ?? _themes[defaultThemeId]!;
  }

  static String migrateLegacyId(String? id) => switch (id) {
    null || '' || 'balanced' || 'spacious' || 'compact' => defaultThemeId,
    _ => id,
  };

  static void _ensureBuiltIns() {
    if (_builtInIds.isNotEmpty) return;
    for (final theme in _builtIns) {
      _themes[theme.id] = theme;
      _builtInIds.add(theme.id);
    }
  }

  static final List<MoyueMarkdownThemeDefinition> _builtIns = [
    MoyueMarkdownThemeDefinition(
      id: defaultThemeId,
      labelBuilder: (context) => context.l10n.moyueAdaptiveMarkdownTheme,
      descriptionBuilder: (context) =>
          context.l10n.moyueAdaptiveMarkdownThemeDescription,
      paletteBuilder: (colors) => MoyueMarkdownPalette(
        surface: colors.surface,
        foreground: colors.onSurface,
        mutedForeground: colors.onSurfaceVariant,
        heading: colors.onSurface,
        link: colors.primary,
        accent: colors.primary,
        blockquoteSurface: colors.surfaceContainerHighest.withValues(
          alpha: 0.44,
        ),
        inlineCodeSurface: colors.surfaceContainerHighest.withValues(
          alpha: 0.72,
        ),
        tableHeaderSurface: colors.surfaceContainerHighest.withValues(
          alpha: 0.58,
        ),
        outline: colors.outlineVariant,
      ),
    ),
    MoyueMarkdownThemeDefinition(
      id: 'paper-warm',
      labelBuilder: (context) => context.l10n.warmPaperMarkdownTheme,
      descriptionBuilder: (context) =>
          context.l10n.warmPaperMarkdownThemeDescription,
      paletteBuilder: (_) => const MoyueMarkdownPalette(
        surface: Color(0xFFFAF5E9),
        foreground: Color(0xFF332D25),
        mutedForeground: Color(0xFF736858),
        heading: Color(0xFF282118),
        link: Color(0xFF8A4D2A),
        accent: Color(0xFFA05A32),
        blockquoteSurface: Color(0xFFEFE4D1),
        inlineCodeSurface: Color(0xFFE9DDC9),
        tableHeaderSurface: Color(0xFFEDE1CD),
        outline: Color(0xFFD4C4AA),
      ),
    ),
    MoyueMarkdownThemeDefinition(
      id: 'github-light',
      labelBuilder: (_) => 'GitHub Light',
      descriptionBuilder: (context) =>
          context.l10n.githubLightMarkdownThemeDescription,
      paletteBuilder: (_) => const MoyueMarkdownPalette(
        surface: Color(0xFFFFFFFF),
        foreground: Color(0xFF1F2328),
        mutedForeground: Color(0xFF59636E),
        heading: Color(0xFF1F2328),
        link: Color(0xFF0969DA),
        accent: Color(0xFF0969DA),
        blockquoteSurface: Color(0xFFF6F8FA),
        inlineCodeSurface: Color(0xFFEFF1F3),
        tableHeaderSurface: Color(0xFFF6F8FA),
        outline: Color(0xFFD0D7DE),
      ),
    ),
    MoyueMarkdownThemeDefinition(
      id: 'github-dark',
      labelBuilder: (_) => 'GitHub Dark',
      descriptionBuilder: (context) =>
          context.l10n.githubDarkMarkdownThemeDescription,
      paletteBuilder: (_) => const MoyueMarkdownPalette(
        surface: Color(0xFF0D1117),
        foreground: Color(0xFFE6EDF3),
        mutedForeground: Color(0xFF8D96A0),
        heading: Color(0xFFF0F6FC),
        link: Color(0xFF58A6FF),
        accent: Color(0xFF2F81F7),
        blockquoteSurface: Color(0xFF161B22),
        inlineCodeSurface: Color(0xFF21262D),
        tableHeaderSurface: Color(0xFF161B22),
        outline: Color(0xFF30363D),
      ),
    ),
    MoyueMarkdownThemeDefinition(
      id: 'solarized-light',
      labelBuilder: (_) => 'Solarized Light',
      descriptionBuilder: (context) =>
          context.l10n.solarizedLightMarkdownThemeDescription,
      paletteBuilder: (_) => const MoyueMarkdownPalette(
        surface: Color(0xFFFDF6E3),
        foreground: Color(0xFF586E75),
        mutedForeground: Color(0xFF839496),
        heading: Color(0xFF073642),
        link: Color(0xFF268BD2),
        accent: Color(0xFF2AA198),
        blockquoteSurface: Color(0xFFEEE8D5),
        inlineCodeSurface: Color(0xFFEEE8D5),
        tableHeaderSurface: Color(0xFFEEE8D5),
        outline: Color(0xFF93A1A1),
      ),
    ),
    MoyueMarkdownThemeDefinition(
      id: 'solarized-dark',
      labelBuilder: (_) => 'Solarized Dark',
      descriptionBuilder: (context) =>
          context.l10n.solarizedDarkMarkdownThemeDescription,
      paletteBuilder: (_) => const MoyueMarkdownPalette(
        surface: Color(0xFF002B36),
        foreground: Color(0xFF839496),
        mutedForeground: Color(0xFF657B83),
        heading: Color(0xFFEEE8D5),
        link: Color(0xFF268BD2),
        accent: Color(0xFF2AA198),
        blockquoteSurface: Color(0xFF073642),
        inlineCodeSurface: Color(0xFF073642),
        tableHeaderSurface: Color(0xFF073642),
        outline: Color(0xFF586E75),
      ),
    ),
  ];
}
