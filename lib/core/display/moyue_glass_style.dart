import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/display_preferences.dart';

/// Shared surface recipe for standalone Moyue glass controls.
///
/// A broad, low-opacity shadow keeps the glass lifted without creating a
/// contact-grey outline around the edge. The shadow becomes slightly softer
/// as the user raises the glass opacity.
List<BoxShadow> moyueGlassShadow(double opacity) {
  final shadowOpacity = 0.065 - (opacity.clamp(0.0, 1.0) * 0.025);
  return [
    BoxShadow(
      color: const Color.fromARGB(
        255,
        0,
        0,
        0,
      ).withValues(alpha: shadowOpacity),
      blurRadius: 20,
      spreadRadius: -3,
      offset: const Offset(0, 6),
    ),
  ];
}

/// The interaction glow and native meniscus absorption remain enabled while
/// the custom outside shadow avoids the package's tighter contact shadow.
LiquidGlassSettings moyueGlassSettings(BuildContext context) {
  final display = DisplayPreferencesScope.maybeOf(context);
  final opacity = display?.glassOpacity ?? 0;
  final inkMode = display?.isInkMode ?? false;
  return LiquidGlassSettings(
    ambientRim: 0.18,
    thickness: 20,
    blur: inkMode ? 1 : 5,
    chromaticAberration: inkMode ? 0 : 0.025,
    lightIntensity: inkMode ? 0.26 : 0.34,
    refractiveIndex: 1.32,
    saturation: inkMode ? 0 : 1.05,
    ambientStrength: inkMode ? 0.04 : 0.12,
    fresnelStrength: inkMode ? 0.08 : 0.12,
    lightAngle: 2.356,
    glowIntensity: inkMode ? 0 : 0.35,
    shadowElevation: 0,
    edgeAbsorption: 0.06,
    shadow: moyueGlassShadow(opacity),
    glassColor: Colors.white.withValues(alpha: opacity),
    // Premium captures can briefly contain transparent pixels while an
    // external texture is attaching. Use the page surface for only those
    // missing samples instead of letting the refraction shader expose black.
    platformViewFallbackColor: Theme.of(context).colorScheme.surface,
  );
}
