import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Moyue's standalone icon button interaction.
///
/// The package's stock icon button adds a white press veil. Moyue instead
/// keeps the surface clear and lets the glass itself follow the pointer before
/// springing home, matching the moving-glass language of the main dock.
class MoyueGlassIconButton extends StatelessWidget {
  const MoyueGlassIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 44,
    this.useOwnLayer = true,
    this.settings,
    super.key,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;
  final bool useOwnLayer;
  final LiquidGlassSettings? settings;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final iconColor = enabled
        ? CupertinoColors.label.resolveFrom(context)
        : CupertinoColors.tertiaryLabel.resolveFrom(context);
    // Premium's inverse-clipped custom shadow can leave a dark cached circle
    // while an own-layer button moves inside a scrolling viewport. Keep the
    // high-quality refraction, but let only the glass shape deform in place and
    // omit that moving shadow from interactive surfaces.
    final interactiveSettings = settings?.copyWith(
      shadowElevation: 0,
      shadow: const [],
    );

    return GlassButton.custom(
      onTap: onPressed ?? () {},
      enabled: enabled,
      label: semanticLabel,
      width: size,
      height: size,
      shape: const LiquidOval(),
      settings: interactiveSettings,
      useOwnLayer: useOwnLayer,
      quality: GlassQuality.premium,
      interactionScale: 1.03,
      stretch: 0.46,
      resistance: 0.02,
      anchorStretch: true,
      persistPressOnDrag: true,
      glowColor: Colors.transparent,
      glowOpacity: 0,
      ambientBaseLight: 0,
      child: IconTheme(
        data: IconThemeData(color: iconColor, size: size * 0.5),
        child: icon,
      ),
    );
  }
}
