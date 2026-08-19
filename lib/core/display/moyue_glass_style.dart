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
      color: const Color.fromARGB(255, 0, 0, 0).withValues(alpha: shadowOpacity),
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
    ambientRim: 1,
    thickness: 30,
    blur: 5,
    chromaticAberration: 0.45,
    lightIntensity: 0.2,
    refractiveIndex: 1.59,
    saturation: 1.1,
    ambientStrength: 1,
    fresnelStrength: 0.4,
    lightAngle: 2.356,
    glowIntensity: 0.75,
    shadowElevation: 0,
    edgeAbsorption: 0.06,
    shadow: moyueGlassShadow(opacity),
    glassColor: Colors.white.withValues(alpha: opacity),
  );
}
