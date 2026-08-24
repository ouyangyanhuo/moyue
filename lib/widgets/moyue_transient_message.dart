import 'package:flutter/material.dart';
import 'package:moyue_application/core/display/display_preferences.dart';

/// Compact document message: the content itself is passive, while tapping
/// anywhere around it dismisses the message.
class MoyueTransientMessageOverlay extends StatelessWidget {
  const MoyueTransientMessageOverlay({
    required this.message,
    required this.bottomInset,
    required this.onDismiss,
    super.key,
  });

  final String? message;
  final double bottomInset;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        DisplayPreferencesScope.maybeOf(context)?.reduceMotion ?? false;
    return IgnorePointer(
      ignoring: message == null,
      child: AnimatedSwitcher(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: message == null
            ? const SizedBox.shrink(key: ValueKey('moyue-message-empty'))
            : _MessageSurface(
                key: ValueKey(message),
                message: message!,
                bottomInset: bottomInset,
                onDismiss: onDismiss,
              ),
      ),
    );
  }
}

class _MessageSurface extends StatelessWidget {
  const _MessageSurface({
    required this.message,
    required this.bottomInset,
    required this.onDismiss,
    super.key,
  });

  final String message;
  final double bottomInset;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      GestureDetector(
        key: const ValueKey('moyue-message-outside-area'),
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
      ),
      Positioned(
        left: 24,
        right: 24,
        bottom: bottomInset,
        child: Center(
          child: GestureDetector(
            key: const ValueKey('moyue-message-content'),
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Material(
                color: Theme.of(context).colorScheme.inverseSurface,
                elevation: 3,
                shadowColor: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onInverseSurface,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
