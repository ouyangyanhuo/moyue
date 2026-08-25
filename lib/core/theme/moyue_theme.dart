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
  static const eInkPaper = Color(0xFFF1EFE6);
  static const eInkSurface = Color(0xFFE5E3DA);
  static const eInk = Color(0xFF292A27);
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

const _inkGreenRamp = <Color>[
  Color(0xFF223020),
  Color(0xFF2D3B28),
  Color(0xFF384631),
  Color(0xFF425039),
  Color(0xFF4D5B42),
  Color(0xFF58664A),
  Color(0xFF637153),
  Color(0xFF6E7C5B),
  Color(0xFF788664),
  Color(0xFF83916C),
  Color(0xFF8E9C75),
  Color(0xFF99A77D),
  Color(0xFFA4B286),
  Color(0xFFAEBC8E),
  Color(0xFFB9C797),
  Color(0xFFC4D29F),
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
  final inkSurface = dark ? _inkGreenRamp[1] : _inkGreenRamp[15];
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
        );
  // Monet supplies the complete Android tonal palette. Moyue only replaces
  // the paper/surface roles that define the reader's eye-friendly canvas;
  // primary, secondary, tertiary and their containers stay system-derived.
  final scheme = generatedScheme.copyWith(
    primary: inkMode ? (dark ? _inkGreenRamp[13] : _inkGreenRamp[3]) : null,
    onPrimary: inkMode ? (dark ? _inkGreenRamp[1] : _inkGreenRamp[15]) : null,
    surface: surface,
    onSurface: inkMode
        ? (dark ? _inkGreenRamp[14] : _inkGreenRamp[0])
        : dark
        ? MoyuePalette.nightInk
        : MoyuePalette.ink,
    surfaceContainer: inkMode
        ? (dark ? _inkGreenRamp[2] : _inkGreenRamp[14])
        : dark
        ? MoyuePalette.nightSurface
        : MoyuePalette.surface,
    surfaceContainerHighest: inkMode
        ? (dark ? _inkGreenRamp[3] : _inkGreenRamp[13])
        : dark
        ? MoyuePalette.nightSurfaceStrong
        : MoyuePalette.paperStrong,
    onSurfaceVariant: inkMode
        ? (dark ? _inkGreenRamp[10] : _inkGreenRamp[5])
        : dark
        ? MoyuePalette.nightMutedInk
        : MoyuePalette.mutedInk,
    outline: inkMode
        ? _inkGreenRamp[7]
        : dark
        ? MoyuePalette.nightHairline
        : MoyuePalette.hairline,
    outlineVariant: inkMode
        ? (dark ? _inkGreenRamp[5] : _inkGreenRamp[11])
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
          grayRamp: _inkGreenRamp,
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
      _inkGreenRamp[dark ? darkIndex : lightIndex];
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
