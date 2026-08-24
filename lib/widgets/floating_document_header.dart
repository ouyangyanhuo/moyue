import 'package:flutter/material.dart';
import 'package:moyue_application/core/i18n/moyue_i18n.dart';
import 'package:moyue_application/core/display/moyue_glass_style.dart';
import 'package:moyue_application/widgets/moyue_glass_icon_button.dart';
import 'package:moyue_application/widgets/moyue_glass_title_pill.dart';

class FloatingDocumentHeader extends StatelessWidget {
  const FloatingDocumentHeader({
    required this.title,
    required this.onBack,
    required this.actionIcon,
    required this.actionLabel,
    required this.onAction,
    this.actionColor,
    this.onTitleTap,
    this.useOwnLayer = true,
    this.foregroundColor,
    super.key,
  });

  final String title;
  final VoidCallback onBack;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback? onAction;
  final Color? actionColor;
  final VoidCallback? onTitleTap;
  final bool useOwnLayer;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      MoyueGlassIconButton(
        onPressed: onBack,
        icon: const Icon(Icons.chevron_left_rounded, size: 22),
        semanticLabel: context.l10n.back,
        size: 44,
        useOwnLayer: useOwnLayer,
        settings: moyueGlassSettings(context),
        foregroundColor: foregroundColor,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: MoyueGlassTitlePill(
          title: title,
          onTap: onTitleTap,
          semanticLabel: context.l10n.renameFolder,
          useOwnLayer: useOwnLayer,
          foregroundColor: foregroundColor,
        ),
      ),
      const SizedBox(width: 8),
      MoyueGlassIconButton(
        icon: Icon(actionIcon, color: actionColor),
        semanticLabel: actionLabel,
        onPressed: onAction,
        useOwnLayer: useOwnLayer,
        settings: moyueGlassSettings(context),
        size: 44,
        foregroundColor: foregroundColor,
      ),
    ],
  );
}
