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
      color: Colors.black.withValues(alpha: shadowOpacity),
      blurRadius: 20,
      spreadRadius: -3,
      offset: const Offset(0, 6),
    ),
  ];
}

/// The interaction glow and native meniscus absorption remain enabled while
/// the custom outside shadow avoids the package's tighter contact shadow.
LiquidGlassSettings moyueGlassSettings(BuildContext context) {
  final opacity = DisplayPreferencesScope.maybeOf(context)?.glassOpacity ?? 0;
  return LiquidGlassSettings(
    glassColor: Colors.white.withValues(alpha: opacity),
    thickness: 12,
    blur: 5,
    chromaticAberration: 0.01,
    lightIntensity: 0.2,
    ambientStrength: 0,
    fresnelStrength: 0,
    refractiveIndex: 1.16,
    saturation: 1.15,
    glowIntensity: 0.75,
    shadowElevation: 0,
    shadow: moyueGlassShadow(opacity),
    edgeAbsorption: 0.06,
  );
}
