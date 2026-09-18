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
      dark ? const Color(0xFF1B1D1C) : const Color(0xFFF0F2EB),
    );
    return DecoratedBox(
      key: const ValueKey('moyue-normal-backdrop'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [top, const Color(0xFF161817), const Color(0xFF111312)]
              : [top, const Color(0xFFEAECE5), const Color(0xFFE3E7DE)],
          stops: const [0, 0.54, 1],
        ),
      ),
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
