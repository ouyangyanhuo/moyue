import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moyue_application/core/display/display_preferences.dart';

abstract final class MoyuePalette {
  // A quiet grey-green paper scale. Keeping every surface away from pure
  // white reduces glare while preserving enough separation between layers.
  static const paper = Color(0xFFECEEE7);
  static const paperStrong = Color(0xFFE0E3DA);
  static const surface = Color(0xFFF2F2EC);
  static const surfaceLowest = Color(0xFFF6F6F1);
  static const surfaceLow = Color(0xFFEFF0E9);
  static const surfaceHigh = Color(0xFFE7E9E1);
  static const surfaceDim = Color(0xFFD7DBD1);
  static const ink = Color(0xFF252A27);
  static const mutedInk = Color(0xFF697068);
  static const moss = Color(0xFFC3C6B8);
  static const hairline = Color(0xFFCFD3C9);
  static const eInkPaper = Color(0xFFDFE0D1);
  static const eInkSurface = Color(0xFFCECFBE);
  static const eInk = Color(0xFF1E201C);
  static const nightPaper = Color(0xFF171A18);
  static const nightSurface = Color(0xFF202420);
  static const nightSurfaceStrong = Color(0xFF2A2F2A);
  static const nightInk = Color(0xFFE7EAE4);
  static const nightMutedInk = Color(0xFFB8BFB7);
  static const nightHairline = Color(0xFF424941);
}

@immutable
class MoyueInkTheme extends ThemeExtension<MoyueInkTheme> {
  const MoyueInkTheme({
    required this.enabled,
    required this.paper,
    required this.ink,
    required this.mutedInk,
    required this.grayRamp,
    required this.textureOpacity,
  });

  final bool enabled;
  final Color paper;
  final Color ink;
  final Color mutedInk;
  final List<Color> grayRamp;
  final double textureOpacity;

  static const disabled = MoyueInkTheme(
    enabled: false,
    paper: Colors.transparent,
    ink: Colors.transparent,
    mutedInk: Colors.transparent,
    grayRamp: <Color>[],
    textureOpacity: 0,
  );

  @override
  MoyueInkTheme copyWith({
    bool? enabled,
    Color? paper,
    Color? ink,
    Color? mutedInk,
    List<Color>? grayRamp,
    double? textureOpacity,
  }) => MoyueInkTheme(
    enabled: enabled ?? this.enabled,
    paper: paper ?? this.paper,
    ink: ink ?? this.ink,
    mutedInk: mutedInk ?? this.mutedInk,
    grayRamp: grayRamp ?? this.grayRamp,
    textureOpacity: textureOpacity ?? this.textureOpacity,
  );

  @override
  MoyueInkTheme lerp(covariant MoyueInkTheme? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// 墨模式 16 级灰阶：模拟真实电子纸的暖中性色。
/// 绿色通道略高于蓝色，呼应品牌苔绿；整体保持中性，长文阅读不腻。
/// 同时供 [InkImageProcessor] 做图片 16 色量化，勿在此之外复制色值。
const List<Color> moyueInkGrayRamp = <Color>[
  Color(0xFF1E201C),
  Color(0xFF272925),
  Color(0xFF30332D),
  Color(0xFF3A3D36),
  Color(0xFF45483F),
  Color(0xFF505349),
  Color(0xFF5C5F53),
  Color(0xFF686B5E),
  Color(0xFF75786A),
  Color(0xFF83867A),
  Color(0xFF909387),
  Color(0xFF9EA294),
  Color(0xFFADB1A2),
  Color(0xFFBDC0AF),
  Color(0xFFCECFBE),
  Color(0xFFDFE0D1),
];

ThemeData buildMoyueTheme({
  required bool inkMode,
  required Brightness brightness,
  required Color seedColor,
  required MoyueFontFamily fontFamily,
  ColorScheme? dynamicColorScheme,
  bool reduceMotion = false,
}) {
  final dark = brightness == Brightness.dark;
  final inkSurface = dark ? moyueInkGrayRamp[1] : moyueInkGrayRamp[15];
  final surface = inkMode
      ? inkSurface
      : dark
      ? MoyuePalette.nightPaper
      : MoyuePalette.paper;
  final generatedScheme = inkMode
      ? _buildInkColorScheme(brightness)
      : dynamicColorScheme?.brightness == brightness
      ? dynamicColorScheme!
      : ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: brightness,
          surface: surface,
          // Material keeps matching foreground roles accessible while making
          // primary, secondary and tertiary accents a little less assertive.
          contrastLevel: -0.1,
        );
  // Monet supplies the complete Android tonal palette. Moyue only replaces
  // the paper/surface roles that define the reader's eye-friendly canvas;
  // primary, secondary, tertiary and their containers stay system-derived.
  final scheme = generatedScheme.copyWith(
    primary: inkMode
        ? (dark ? moyueInkGrayRamp[13] : moyueInkGrayRamp[3])
        : null,
    onPrimary: inkMode
        ? (dark ? moyueInkGrayRamp[1] : moyueInkGrayRamp[15])
        : null,
    surface: surface,
    surfaceDim: inkMode
        ? (dark ? moyueInkGrayRamp[2] : moyueInkGrayRamp[13])
        : dark
        ? MoyuePalette.nightPaper
        : MoyuePalette.surfaceDim,
    surfaceBright: inkMode
        ? (dark ? moyueInkGrayRamp[3] : moyueInkGrayRamp[15])
        : dark
        ? MoyuePalette.nightSurfaceStrong
        : MoyuePalette.surfaceLowest,
    surfaceContainerLowest: inkMode
        ? (dark ? moyueInkGrayRamp[0] : moyueInkGrayRamp[15])
        : dark
        ? MoyuePalette.nightPaper
        : MoyuePalette.surfaceLowest,
    surfaceContainerLow: inkMode
        ? (dark ? moyueInkGrayRamp[2] : moyueInkGrayRamp[14])
        : dark
        ? MoyuePalette.nightSurface
        : MoyuePalette.surfaceLow,
    onSurface: inkMode
        ? (dark ? moyueInkGrayRamp[14] : moyueInkGrayRamp[0])
        : dark
        ? MoyuePalette.nightInk
        : MoyuePalette.ink,
    surfaceContainer: inkMode
        ? (dark ? moyueInkGrayRamp[2] : moyueInkGrayRamp[14])
        : dark
        ? MoyuePalette.nightSurface
        : MoyuePalette.surface,
    surfaceContainerHighest: inkMode
        ? (dark ? moyueInkGrayRamp[3] : moyueInkGrayRamp[13])
        : dark
        ? MoyuePalette.nightSurfaceStrong
        : MoyuePalette.paperStrong,
    surfaceContainerHigh: inkMode
        ? (dark ? moyueInkGrayRamp[3] : moyueInkGrayRamp[13])
        : dark
        ? MoyuePalette.nightSurfaceStrong
        : MoyuePalette.surfaceHigh,
    onSurfaceVariant: inkMode
        ? (dark ? moyueInkGrayRamp[10] : moyueInkGrayRamp[5])
        : dark
        ? MoyuePalette.nightMutedInk
        : MoyuePalette.mutedInk,
    outline: inkMode
        ? moyueInkGrayRamp[7]
        : dark
        ? MoyuePalette.nightHairline
        : MoyuePalette.hairline,
    outlineVariant: inkMode
        ? (dark ? moyueInkGrayRamp[5] : moyueInkGrayRamp[11])
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
    extensions: [
      if (inkMode)
        MoyueInkTheme(
          enabled: true,
          paper: scheme.surface,
          ink: scheme.onSurface,
          mutedInk: scheme.onSurfaceVariant,
          grayRamp: moyueInkGrayRamp,
          textureOpacity: dark ? 0.16 : 0.2,
        )
      else
        MoyueInkTheme.disabled,
    ],
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
  MoyueFontFamily.ink => switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.fuchsia => 'serif',
    TargetPlatform.iOS || TargetPlatform.macOS => 'Songti SC',
    TargetPlatform.windows => 'SimSun',
    TargetPlatform.linux => 'Noto Serif CJK SC',
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
  MoyueFontFamily.ink => const [
    'Noto Serif CJK SC',
    'Noto Serif SC',
    'Songti SC',
    'STSong',
    'Noto Sans CJK SC',
    'Noto Sans SC',
    'serif',
  ],
};

ColorScheme _buildInkColorScheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  Color tone(int lightIndex, int darkIndex) =>
      moyueInkGrayRamp[dark ? darkIndex : lightIndex];
  return ColorScheme.fromSeed(
    seedColor: tone(3, 13),
    brightness: brightness,
    surface: tone(15, 1),
  ).copyWith(
    primary: tone(3, 13),
    onPrimary: tone(15, 1),
    primaryContainer: tone(12, 4),
    onPrimaryContainer: tone(1, 14),
    primaryFixed: tone(12, 4),
    primaryFixedDim: tone(10, 6),
    onPrimaryFixed: tone(1, 14),
    onPrimaryFixedVariant: tone(4, 11),
    secondary: tone(4, 12),
    onSecondary: tone(15, 1),
    secondaryContainer: tone(13, 3),
    onSecondaryContainer: tone(1, 14),
    secondaryFixed: tone(13, 3),
    secondaryFixedDim: tone(11, 5),
    onSecondaryFixed: tone(1, 14),
    onSecondaryFixedVariant: tone(5, 10),
    tertiary: tone(5, 11),
    onTertiary: tone(15, 1),
    tertiaryContainer: tone(12, 4),
    onTertiaryContainer: tone(1, 14),
    tertiaryFixed: tone(12, 4),
    tertiaryFixedDim: tone(10, 6),
    onTertiaryFixed: tone(1, 14),
    onTertiaryFixedVariant: tone(5, 10),
    error: tone(2, 13),
    onError: tone(15, 1),
    errorContainer: tone(12, 4),
    onErrorContainer: tone(1, 14),
    surface: tone(15, 1),
    onSurface: tone(0, 14),
    surfaceDim: tone(13, 2),
    surfaceBright: tone(15, 3),
    surfaceContainerLowest: tone(15, 0),
    surfaceContainerLow: tone(14, 2),
    surfaceContainer: tone(14, 2),
    surfaceContainerHigh: tone(13, 3),
    surfaceContainerHighest: tone(12, 4),
    onSurfaceVariant: tone(5, 10),
    outline: tone(7, 8),
    outlineVariant: tone(11, 5),
    inverseSurface: tone(1, 14),
    onInverseSurface: tone(14, 1),
    inversePrimary: tone(12, 4),
    surfaceTint: tone(3, 13),
    shadow: tone(0, 0),
    scrim: tone(0, 0),
  );
}
