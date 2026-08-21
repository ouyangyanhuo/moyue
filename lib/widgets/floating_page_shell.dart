import 'package:flutter/material.dart';
import 'package:moyue_application/widgets/expandable_glass_search.dart';

/// 首页（阅读/订阅/设置）通用骨架。
///
/// 职责拆分与阅读页浮动头部保持一致：
/// - 标题/副标题位于滚动区内（[FloatingPageTitle]），随列表滚动正常收起；
/// - 玻璃按钮（添加、搜索）固定在滚动视口之外的顶部浮层。
///
/// premium 玻璃的纹理捕获一旦进入滚动视口，按压位移时就会采样失效并
/// 塌缩成黑色圆球；阅读页的返回/编辑按钮正是靠固定浮层才拥有完美的
/// 按压效果，本组件让首页按钮走完全相同的渲染路径。
class FloatingPageShell extends StatelessWidget {
  const FloatingPageShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.searchHint,
    this.onSearch,
    this.showSearch = true,
    this.trailing,
    super.key,
  });

  /// 随列表滚动的标题文案。
  final String title;

  /// 随列表滚动的副标题文案。
  final String subtitle;

  /// 固定在顶部浮层的操作按钮（如新建/删除），显示在搜索按钮左侧。
  final Widget? trailing;

  final String? searchHint;
  final ValueChanged<String>? onSearch;
  final bool showSearch;

  /// 页面滚动内容，通常是 CustomScrollView。
  final Widget child;

  /// 标题块右侧需预留的宽度，避免静止时标题钻到固定按钮下方：
  /// 搜索钮 44 + 间距 8 + 操作钮 44 + 右边距 18 + 余量 10。
  static const double actionsReservedWidth = 124;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 18, 0),
              child: Align(
                alignment: Alignment.centerRight,
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
        ),
      ],
    );
  }
}

/// 滚动区顶部的标题块：作为第一个 sliver 使用，随列表一起滚走、正常收起。
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
        16,
        FloatingPageShell.actionsReservedWidth,
        4,
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
