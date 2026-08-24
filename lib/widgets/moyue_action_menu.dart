import 'package:flutter/material.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/widgets/moyue_create_menu.dart';

/// 与“新建或导入”入口一致的 Material 底部弹层。
///
/// 弹层只返回用户选择，实际的移动、分享或删除会在弹层完全关闭后执行，
/// 避免操作过程中继续持有即将销毁的 sheet context。
class MoyueMenuAction<T> {
  const MoyueMenuAction({
    required this.value,
    required this.label,
    required this.icon,
    this.destructive = false,
    this.indentLevel = 0,
  });

  final T value;
  final String label;
  final IconData icon;
  final bool destructive;
  final int indentLevel;
}

Future<T?> showMoyueActionMenu<T>({
  required BuildContext context,
  required List<MoyueMenuAction<T>> actions,
  String? title,
  String? message,
}) => showModalBottomSheet<T>(
  context: context,
  backgroundColor: Colors.transparent,
  useSafeArea: false,
  isScrollControlled: true,
  enableDrag: false,
  isDismissible: true,
  sheetAnimationStyle:
      DisplayPreferencesScope.maybeOf(context)?.reduceMotion ?? false
      ? AnimationStyle.noAnimation
      : null,
  builder: (sheetContext) => MoyueMaterialSheet(
    child: Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 8),
            children: [
              if (title != null || message != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(title, style: theme.textTheme.titleLarge),
                      if (title != null && message != null)
                        const SizedBox(height: 4),
                      if (message != null)
                        Text(
                          message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              for (final action in actions)
                Padding(
                  padding: EdgeInsets.only(
                    left: action.indentLevel.clamp(0, 5) * 14.0,
                  ),
                  child: ListTile(
                    leading: Icon(
                      action.icon,
                      color: action.destructive
                          ? theme.colorScheme.error
                          : null,
                    ),
                    title: Text(
                      action.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: action.destructive
                          ? TextStyle(color: theme.colorScheme.error)
                          : null,
                    ),
                    onTap: () => Navigator.pop(context, action.value),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  ),
);
