import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/display_preferences.dart';

/// Shared surface recipe for standalone Moyue glass controls.
///
/// The interaction glow remains enabled, while the shader's outside shadow
/// and dark edge absorption are disabled so high tint opacity stays clean.
LiquidGlassSettings moyueGlassSettings(BuildContext context) {
  final opacity =
      DisplayPreferencesScope.maybeOf(context)?.glassOpacity ?? 0.12;
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
    edgeAbsorption: 0.06,
  );
}
