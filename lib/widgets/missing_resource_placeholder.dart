import 'package:flutter/material.dart';
import 'package:moyue_application/core/i18n/moyue_i18n.dart';

/// A bounded, noninteractive fallback for unavailable document attachments.
class MissingResourcePlaceholder extends StatelessWidget {
  const MissingResourcePlaceholder({super.key});

  @override
  Widget build(BuildContext context) => SelectionContainer.disabled(
    child: Semantics(
      label: context.l10n.referencedResourceMissing,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.referencedResourceMissing,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
