import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/moyue_glass_style.dart';
import 'package:moyue_application/widgets/scrolling_title.dart';

class FloatingDocumentHeader extends StatelessWidget {
  const FloatingDocumentHeader({
    required this.title,
    required this.onBack,
    required this.actionIcon,
    required this.actionLabel,
    required this.onAction,
    this.actionColor,
    this.onTitleTap,
    super.key,
  });

  final String title;
  final VoidCallback onBack;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback? onAction;
  final Color? actionColor;
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      GlassIconButton(
        onPressed: onBack,
        icon: const Icon(Icons.chevron_left_rounded, size: 22),
        semanticLabel: '返回',
        size: 44,
        useOwnLayer: true,
        settings: moyueGlassSettings(context),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Semantics(
          button: onTitleTap != null,
          label: onTitleTap == null ? null : '修改文件夹名称',
          child: GestureDetector(
            onTap: onTitleTap,
            child: GlassContainer(
              height: 42,
              useOwnLayer: true,
              settings: moyueGlassSettings(context),
              shape: const LiquidRoundedSuperellipse(borderRadius: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: ScrollingTitle(
                title,
                autoScroll: true,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      GlassIconButton(
        icon: Icon(actionIcon, color: actionColor),
        semanticLabel: actionLabel,
        onPressed: onAction,
        useOwnLayer: true,
        settings: moyueGlassSettings(context),
        size: 44,
      ),
    ],
  );
}
