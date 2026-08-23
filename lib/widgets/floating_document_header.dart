import 'package:flutter/material.dart';
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
    this.platformViewBackdrop = false,
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
  final bool platformViewBackdrop;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      MoyueGlassIconButton(
        onPressed: onBack,
        icon: const Icon(Icons.chevron_left_rounded, size: 22),
        semanticLabel: '返回',
        size: 44,
        useOwnLayer: useOwnLayer,
        platformViewBackdrop: platformViewBackdrop,
        settings: moyueGlassSettings(context),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: MoyueGlassTitlePill(
          title: title,
          onTap: onTitleTap,
          semanticLabel: '修改文件夹名称',
          useOwnLayer: useOwnLayer,
          platformViewBackdrop: platformViewBackdrop,
        ),
      ),
      const SizedBox(width: 8),
      MoyueGlassIconButton(
        icon: Icon(actionIcon, color: actionColor),
        semanticLabel: actionLabel,
        onPressed: onAction,
        useOwnLayer: useOwnLayer,
        platformViewBackdrop: platformViewBackdrop,
        settings: moyueGlassSettings(context),
        size: 44,
      ),
    ],
  );
}
