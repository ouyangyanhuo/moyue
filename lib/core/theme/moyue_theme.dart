import 'package:flutter/material.dart';

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
}

ThemeData buildMoyueTheme({required bool inkMode}) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: inkMode ? const Color(0xFF3F423E) : MoyuePalette.moss,
        brightness: Brightness.light,
        surface: inkMode ? MoyuePalette.eInkPaper : MoyuePalette.paper,
      ).copyWith(
        primary: inkMode ? const Color(0xFF323531) : MoyuePalette.moss,
        onPrimary: Colors.white,
        surface: inkMode ? MoyuePalette.eInkPaper : MoyuePalette.paper,
        onSurface: inkMode ? MoyuePalette.eInk : MoyuePalette.ink,
        surfaceContainer: inkMode
            ? MoyuePalette.eInkSurface
            : MoyuePalette.surface,
        surfaceContainerHighest: inkMode
            ? const Color(0xFFDADAD6)
            : MoyuePalette.paperStrong,
        outline: inkMode ? const Color(0xFF8B8D88) : MoyuePalette.hairline,
        outlineVariant: inkMode
            ? const Color(0xFFC4C5C1)
            : MoyuePalette.hairline,
      );
  final base = ThemeData.light(useMaterial3: true).textTheme;
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
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: textTheme,
    splashFactory: inkMode ? NoSplash.splashFactory : InkSparkle.splashFactory,
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
