import 'package:flutter/material.dart';

/// WCAG-style contrast ratio used to keep side-loaded reader themes legible.
double moyueContrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground
      .withValues(alpha: 1)
      .computeLuminance();
  final backgroundLuminance = background
      .withValues(alpha: 1)
      .computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

Color moyueOpaqueOver(Color color, Color background) => color.a >= 1
    ? color
    : Color.alphaBlend(color, background.withValues(alpha: 1));

/// Preserves the original hue whenever possible, moving it only as far toward
/// black or white as required to be readable on every supplied surface.
Color moyueEnsureContrastAcross(
  Color color,
  Iterable<Color> backgrounds, {
  double minimumRatio = 4.5,
}) {
  final surfaces = backgrounds
      .map((background) => background.withValues(alpha: 1))
      .toList(growable: false);
  if (surfaces.isEmpty) return color.withValues(alpha: 1);
  final opaque = color.withValues(alpha: 1);
  double lowestRatio(Color candidate) => surfaces
      .map((surface) => moyueContrastRatio(candidate, surface))
      .reduce((first, second) => first < second ? first : second);

  if (lowestRatio(opaque) >= minimumRatio) return opaque;
  final blackRatio = lowestRatio(Colors.black);
  final whiteRatio = lowestRatio(Colors.white);
  final target = blackRatio >= whiteRatio ? Colors.black : Colors.white;
  if (lowestRatio(target) < minimumRatio) return target;

  var low = 0.0;
  var high = 1.0;
  for (var index = 0; index < 18; index++) {
    final amount = (low + high) / 2;
    final candidate = Color.lerp(opaque, target, amount)!;
    if (lowestRatio(candidate) >= minimumRatio) {
      high = amount;
    } else {
      low = amount;
    }
  }
  return Color.lerp(opaque, target, high)!.withValues(alpha: 1);
}

Color moyueEnsureContrast(
  Color color,
  Color background, {
  double minimumRatio = 4.5,
}) =>
    moyueEnsureContrastAcross(color, [background], minimumRatio: minimumRatio);
