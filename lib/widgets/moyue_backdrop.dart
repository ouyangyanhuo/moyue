import 'package:flutter/material.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/theme/moyue_theme.dart';

class MoyueBackdrop extends StatelessWidget {
  const MoyueBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final isInk =
        DisplayPreferencesScope.of(context).mode == ReadingDisplayMode.ink;
    if (isInk) return const ColoredBox(color: MoyuePalette.eInkPaper);

    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF9F6EE), Color(0xFFF3EEE4), Color(0xFFE9EFE5)],
          stops: [0, 0.58, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -90, right: -80, child: _SoftCircle(size: 260)),
          Positioned(bottom: 70, left: -120, child: _SoftCircle(size: 320)),
        ],
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0x2EB7C4AE),
      ),
    ),
  );
}
