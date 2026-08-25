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

    if (theme.brightness == Brightness.dark) {
      final accent = theme.colorScheme.primary;
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF181B19), Color(0xFF151816), Color(0xFF111512)],
            stops: [0, 0.58, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -80,
              child: _SoftCircle(size: 260, color: accent),
            ),
            Positioned(
              bottom: 70,
              left: -120,
              child: _SoftCircle(size: 320, color: accent),
            ),
          ],
        ),
      );
    }

    final accent = theme.colorScheme.primary;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF9F6EE), Color(0xFFF3EEE4), Color(0xFFE9EFE5)],
          stops: [0, 0.58, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -80,
            child: _SoftCircle(size: 260, color: accent),
          ),
          Positioned(
            bottom: 70,
            left: -120,
            child: _SoftCircle(size: 320, color: accent),
          ),
        ],
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

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.13),
      ),
    ),
  );
}
