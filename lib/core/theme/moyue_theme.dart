import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moyue_application/core/display/display_preferences.dart';

abstract final class MoyuePalette {
  static const paper = Color(0xFFF7F3E9);
  static const paperStrong = Color(0xFFEFE9DC);
  static const surface = Color(0xFFFFFCF5);
  static const ink = Color(0xFF252A27);
  static const mutedInk = Color(0xFF697068);
  static const moss = Color(0xFF6D7967);
  static const hairline = Color(0xFFD9D4C8);
  static const eInkPaper = Color(0xFFF2F2EF);
  static const eInkSurface = Color(0xFFE7E7E3);
  static const eInk = Color(0xFF181A18);
  static const nightPaper = Color(0xFF171A18);
  static const nightSurface = Color(0xFF202420);
  static const nightSurfaceStrong = Color(0xFF2A2F2A);
  static const nightInk = Color(0xFFE7EAE4);
  static const nightMutedInk = Color(0xFFB8BFB7);
  static const nightHairline = Color(0xFF424941);
}

ThemeData buildMoyueTheme({
  required bool inkMode,
  required Brightness brightness,
  required Color seedColor,
  required MoyueFontFamily fontFamily,
  ColorScheme? dynamicColorScheme,
  bool reduceMotion = false,
}) {
  final dark = brightness == Brightness.dark;
  final surface = inkMode
      ? MoyuePalette.eInkPaper
      : dark
      ? MoyuePalette.nightPaper
      : MoyuePalette.paper;
  final generatedScheme =
      !inkMode && dynamicColorScheme?.brightness == brightness
      ? dynamicColorScheme!
      : ColorScheme.fromSeed(
          seedColor: inkMode ? const Color(0xFF3F423E) : seedColor,
          brightness: brightness,
          surface: surface,
        );
  // Monet supplies the complete Android tonal palette. Moyue only replaces
  // the paper/surface roles that define the reader's eye-friendly canvas;
  // primary, secondary, tertiary and their containers stay system-derived.
  final scheme = generatedScheme.copyWith(
    primary: inkMode ? const Color(0xFF323531) : null,
    onPrimary: inkMode ? Colors.white : null,
    surface: surface,
    onSurface: inkMode
        ? MoyuePalette.eInk
        : dark
        ? MoyuePalette.nightInk
        : MoyuePalette.ink,
    surfaceContainer: inkMode
        ? MoyuePalette.eInkSurface
        : dark
        ? MoyuePalette.nightSurface
        : MoyuePalette.surface,
    surfaceContainerHighest: inkMode
        ? const Color(0xFFDADAD6)
        : dark
        ? MoyuePalette.nightSurfaceStrong
        : MoyuePalette.paperStrong,
    onSurfaceVariant: dark ? MoyuePalette.nightMutedInk : MoyuePalette.mutedInk,
    outline: inkMode
        ? const Color(0xFF8B8D88)
        : dark
        ? MoyuePalette.nightHairline
        : MoyuePalette.hairline,
    outlineVariant: inkMode
        ? const Color(0xFFC4C5C1)
        : dark
        ? MoyuePalette.nightHairline
        : MoyuePalette.hairline,
  );
  final selectedFontFamily = _fontFamilyName(fontFamily);
  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    fontFamily: selectedFontFamily,
    fontFamilyFallback: _fontFamilyFallback(fontFamily),
  ).textTheme;
  final textTheme = base
      .copyWith(
        headlineLarge: base.headlineLarge?.copyWith(
          fontSize: 30,
          height: 1.18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          fontSize: 24,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.35,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: base.bodyLarge?.copyWith(
          fontSize: 17,
          height: 1.72,
          letterSpacing: 0.08,
        ),
        bodyMedium: base.bodyMedium?.copyWith(fontSize: 15, height: 1.62),
        bodySmall: base.bodySmall?.copyWith(fontSize: 13, height: 1.45),
        labelLarge: base.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      )
      .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    fontFamily: selectedFontFamily,
    fontFamilyFallback: _fontFamilyFallback(fontFamily),
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: textTheme,
    splashFactory: inkMode || reduceMotion
        ? NoSplash.splashFactory
        : InkSparkle.splashFactory,
    dividerColor: scheme.outlineVariant,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      titleTextStyle: textTheme.titleLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.58),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainer,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: 1,
    ),
  );
}

String? _fontFamilyName(MoyueFontFamily family) => switch (family) {
  MoyueFontFamily.system => null,
  MoyueFontFamily.claude => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'serif',
    TargetPlatform.iOS || TargetPlatform.macOS => 'New York',
    TargetPlatform.windows => 'Georgia',
    TargetPlatform.linux => 'Noto Serif',
    TargetPlatform.fuchsia => 'serif',
  },
  MoyueFontFamily.rounded => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'sans-serif-rounded',
    TargetPlatform.iOS || TargetPlatform.macOS => 'SF Pro Rounded',
    TargetPlatform.windows => 'Segoe UI Variable',
    TargetPlatform.linux => 'Ubuntu',
    TargetPlatform.fuchsia => 'Roboto',
  },
};

List<String> _fontFamilyFallback(MoyueFontFamily family) => switch (family) {
  MoyueFontFamily.system => const [],
  MoyueFontFamily.claude => const [
    'Source Serif 4',
    'Noto Serif',
    'Noto Serif CJK SC',
    'Songti SC',
    'STSong',
    'Georgia',
  ],
  MoyueFontFamily.rounded => const [
    'SF Pro Rounded',
    'Arial Rounded MT Bold',
    'Noto Sans CJK SC',
    'Noto Sans SC',
  ],
};
