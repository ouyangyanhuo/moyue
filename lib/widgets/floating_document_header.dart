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
      MoyueGlassIconButton(
        onPressed: onBack,
        icon: const Icon(Icons.chevron_left_rounded, size: 22),
        semanticLabel: '返回',
        size: 44,
        useOwnLayer: true,
        settings: moyueGlassSettings(context),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: MoyueGlassTitlePill(
          title: title,
          onTap: onTitleTap,
          semanticLabel: '修改文件夹名称',
        ),
      ),
      const SizedBox(width: 8),
      MoyueGlassIconButton(
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
