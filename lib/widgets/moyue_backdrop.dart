import 'package:flutter/material.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/theme/moyue_theme.dart';

class MoyueBackdrop extends StatelessWidget {
  const MoyueBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = DisplayPreferencesScope.of(context);
    final isInk = display.mode == ReadingDisplayMode.ink;
    if (isInk) return const _InkPaperBackdrop();

    final dark = theme.brightness == Brightness.dark;
    final accentWash = theme.colorScheme.primary.withValues(
      alpha: dark ? 0.035 : 0.025,
    );
    final top = Color.alphaBlend(
      accentWash,
      dark ? const Color(0xFF1B1D1C) : const Color(0xFFF3F0E7),
    );
    return RepaintBoundary(
      child: DecoratedBox(
        key: const ValueKey('moyue-normal-backdrop'),
        decoration: BoxDecoration(
          image: moyuePaperGrain(top),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? [top, const Color(0xFF161817), const Color(0xFF111312)]
                : [top, const Color(0xFFECEAE1), const Color(0xFFE6E4DA)],
            stops: const [0, 0.54, 1],
          ),
        ),
      ),
    );
  }
}

/// Fixed-scale, seamless fibers. Reuses one decoded asset; no per-frame noise,
/// shader, blur, or full-screen opacity layer. The source's sparse translucent
/// fibers are tinted gently; dark paper uses an even lower contrast.
DecorationImage moyuePaperGrain(Color surface) {
  final dark = ThemeData.estimateBrightnessForColor(surface) == Brightness.dark;
  return DecorationImage(
    image: const AssetImage('assets/textures/ink_paper_fibers.png'),
    repeat: ImageRepeat.repeat,
    fit: BoxFit.none,
    alignment: Alignment.topLeft,
    scale: 2,
    opacity: dark ? 0.10 : 0.16,
    colorFilter: ColorFilter.mode(
      dark ? const Color(0xFFE0DCCF) : const Color(0xFF514C40),
      BlendMode.srcIn,
    ),
    filterQuality: FilterQuality.low,
  );
}

/// Put texture behind content, never over text, photos, or embedded web pages.
class MoyuePaperSurface extends StatelessWidget {
  const MoyuePaperSurface({
    required this.color,
    required this.child,
    super.key,
  });

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (DisplayPreferencesScope.maybeOf(context)?.isInkMode ?? false) {
      return ColoredBox(color: color, child: child);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  image: moyuePaperGrain(color),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _InkPaperBackdrop extends StatelessWidget {
  const _InkPaperBackdrop();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.extension<MoyueInkTheme>()!;
    return RepaintBoundary(
      child: ColoredBox(color: ink.paper, child: const MoyueInkPaperTexture()),
    );
  }
}

class MoyueInkPaperTexture extends StatelessWidget {
  const MoyueInkPaperTexture({super.key});

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).extension<MoyueInkTheme>();
    if (ink == null || !ink.enabled) return const SizedBox.expand();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: RepaintBoundary(
        child: Image.asset(
          'assets/textures/ink_paper_fibers.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          color: dark ? ink.grayRamp[14] : ink.grayRamp[0],
          colorBlendMode: BlendMode.srcIn,
          opacity: AlwaysStoppedAnimation<double>(ink.textureOpacity),
          gaplessPlayback: true,
        ),
      ),
    );
  }
}
