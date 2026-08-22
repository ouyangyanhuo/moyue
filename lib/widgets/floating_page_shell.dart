import 'package:flutter/material.dart';
import 'package:moyue_application/widgets/expandable_glass_search.dart';

/// 首页（阅读/订阅/设置）通用骨架。
///
/// 标题/副标题属于滚动内容（由 [FloatingPageTitle] 作为首个 sliver 提供，
/// 随页面滚动收起）；添加/搜索按钮固定在右上角浮层，保持 premium
/// 独立渲染，不与任何玻璃容器嵌套。
class FloatingPageShell extends StatelessWidget {
  const FloatingPageShell({
    required this.child,
    this.searchHint,
    this.onSearch,
    this.showSearch = true,
    this.trailing,
    super.key,
  });

  /// 固定在右上角的操作按钮（如新建/删除）。
  final Widget? trailing;

  final String? searchHint;
  final ValueChanged<String>? onSearch;
  final bool showSearch;

  /// 页面滚动内容，通常是 CustomScrollView。
  final Widget child;

  /// 标题区为右侧按钮预留的宽度（搜索 44 + 间距 8 + 操作 44 + 边距）。
  static const double actionsReserve = 124;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 18, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (trailing != null) ...[
                    trailing!,
                    const SizedBox(width: 8),
                  ],
                  if (showSearch && onSearch != null)
                    ExpandableGlassSearch(
                      hintText: searchHint ?? '',
                      onChanged: onSearch!,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 滚动区顶部的标题块：原始 PageHeading 几何，随页面滚动正常收起。
class FloatingPageTitle extends StatelessWidget {
  const FloatingPageTitle({
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        22,
        18,
        FloatingPageShell.actionsReserve,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
