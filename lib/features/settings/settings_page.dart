import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/display/moyue_glass_style.dart';
import 'package:moyue_application/services/app_restart_service.dart';
import 'package:moyue_application/services/app_version_service.dart';
import 'package:moyue_application/services/debug_service.dart';
import 'package:moyue_application/widgets/floating_page_shell.dart';
import 'package:moyue_application/widgets/expandable_glass_search.dart';
import 'package:moyue_application/widgets/moyue_create_menu.dart';
import 'package:moyue_application/widgets/section_label.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  static const _fontScales = <double>[0.85, 0.95, 1.0, 1.1, 1.2, 1.3, 1.4];
  String _query = '';
  final _searchKey = GlobalKey<ExpandableGlassSearchState>();

  void openSearch() => _searchKey.currentState?.open();

  Future<void> showAbout() {
    final version = AppVersionService.displayVersion();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => _AboutSheet(version: version),
    );
  }

  Future<void> _showSettingDetail({
    required WidgetBuilder contentBuilder,
    Listenable? listenable,
  }) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: false,
    builder: (sheetContext) => MoyueMaterialSheet(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
        ),
        child: SingleChildScrollView(
          child: listenable == null
              ? Builder(builder: contentBuilder)
              : ListenableBuilder(
                  listenable: listenable,
                  builder: (context, _) => contentBuilder(context),
                ),
        ),
      ),
    ),
  );

  Future<void> _showSwitchDetail({
    required Listenable listenable,
    required IconData icon,
    required String title,
    required String description,
    required bool Function() value,
    required ValueChanged<bool>? onChanged,
    String Function(bool value)? statusBuilder,
  }) => _showSettingDetail(
    listenable: listenable,
    contentBuilder: (context) {
      final current = value();
      return _SettingDetailSheet(
        key: ValueKey('$title-setting-detail'),
        icon: icon,
        title: title,
        description: description,
        status: statusBuilder?.call(current) ?? (current ? '已开启' : '已关闭'),
        control: Align(
          alignment: Alignment.centerRight,
          child: _GlassSwitchControl(
            touchAreaKey: ValueKey('$title-detail-switch-touch-area'),
            value: current,
            onChanged: onChanged,
            semanticLabel: title,
          ),
        ),
      );
    },
  );

  Future<void> _showContrastDetail(DisplayModeController display) =>
      _showSettingDetail(
        listenable: display,
        contentBuilder: (context) => _SettingDetailSheet(
          key: const ValueKey('对比度-setting-detail'),
          icon: Icons.contrast_rounded,
          title: '对比度',
          description: '调整纸张背景与文字、图标之间的明暗差异。数值越高，前景与背景的区分越明显。',
          status: '${(display.contrast * 100).round()}%',
          control: _ExpandedGlassSlider(
            touchAreaKey: const ValueKey('contrast-slider-touch-area'),
            value: display.contrast,
            onChanged: display.setContrast,
          ),
        ),
      );

  Future<void> _showNativeEngineDetail(
    DisplayModeController display,
  ) => _showSettingDetail(
    listenable: display,
    contentBuilder: (context) {
      final htmlUsesWebView = display.htmlWebViewEnabled;
      return _SettingDetailSheet(
        key: const ValueKey('原生排版引擎-setting-detail'),
        icon: Icons.auto_awesome_motion_outlined,
        title: '原生排版引擎',
        description: htmlUsesWebView
            ? 'Markdown 始终使用 Flutter 原生高性能引擎渲染，不依赖 WebView。当前 HTML 已设置为使用网页引擎。'
            : 'Markdown 与 HTML 当前都使用 Flutter 原生组件排版。Markdown 始终不会依赖 WebView。',
        status: htmlUsesWebView ? 'Markdown' : 'Markdown 与 HTML',
      );
    },
  );

  Future<void> _chooseFontSize(DisplayModeController display) async {
    final initialIndex = _nearestFontScaleIndex(display.appFontScale);
    final selected = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => _FontScalePickerSheet(
        scales: _fontScales,
        initialIndex: initialIndex,
      ),
    );
    if (selected == null || selected == display.appFontScale || !mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('需要重启墨阅'),
        content: const Text('应用新的软件字体大小后，墨阅会立即重启，以确保所有页面同步生效。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('应用并重启'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await display.setAppFontScale(selected);
    final restarted = await AppRestartService.restart();
    if (!restarted && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('字号已保存，请手动重新打开墨阅以完全生效')));
    }
  }

  int _nearestFontScaleIndex(double value) {
    var result = 0;
    var distance = double.infinity;
    for (var index = 0; index < _fontScales.length; index++) {
      final next = (_fontScales[index] - value).abs();
      if (next < distance) {
        result = index;
        distance = next;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final display = DisplayPreferencesScope.of(context);
    final debug = DebugService.instance;
    final query = _query.trim();
    final showDisplay = query.isEmpty || '显示墨模式对比度护眼字体字号大小'.contains(query);
    final showReading =
        query.isEmpty || '阅读动画翻页动效HTML WebView网页原生预见性返回手势'.contains(query);
    final showDebug = query.isEmpty || '调试帧率实时显示'.contains(query);
    final debugVisible = debug.enabled && showDebug;

    // 标题随页面滚动正常收起；搜索按钮固定在视口之外的浮层里
    // （与阅读页浮动头部一致），获得完全相同的 premium 按压效果。
    return ListenableBuilder(
      listenable: debug,
      builder: (context, _) => FloatingPageShell(
        searchHint: '搜索设置',
        searchKey: _searchKey,
        onSearch: (value) => setState(() => _query = value),
        child: CustomScrollView(
          key: const PageStorageKey('settings-scroll'),
          slivers: [
            const SliverToBoxAdapter(
              child: FloatingPageTitle(title: '设置', subtitle: '墨模式 · 回归墨水屏'),
            ),
            if (showDisplay) ...[
              const SliverToBoxAdapter(child: SectionLabel('显示')),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  children: [
                    _GlassSwitchTile(
                      value: false,
                      onChanged: null,
                      icon: Icons.water_drop_outlined,
                      title: '墨模式',
                      subtitle: '暂未开放',
                      onDetails: () => _showSwitchDetail(
                        listenable: display,
                        icon: Icons.water_drop_outlined,
                        title: '墨模式',
                        description:
                            '是模仿电子墨水屏的显示效果，关闭各类动画为纯粹阅读而生的模式。接口已经预留，当前版本暂未开放。',
                        value: () => false,
                        onChanged: null,
                        statusBuilder: (_) => '暂未开放',
                      ),
                    ),
                    const Divider(indent: 56),
                    _ContrastSettingTile(
                      icon: Icons.contrast_rounded,
                      title: '对比度',
                      value: display.contrast,
                      onChanged: display.setContrast,
                      onDetails: () => _showContrastDetail(display),
                    ),
                    const Divider(indent: 56),
                    _SettingSummaryTile(
                      icon: Icons.text_fields_rounded,
                      title: '软件字体大小',
                      status: '${(display.appFontScale * 100).round()}%',
                      onTap: () => _chooseFontSize(display),
                    ),
                  ],
                ),
              ),
            ],
            if (showReading) ...[
              const SliverToBoxAdapter(child: SectionLabel('阅读')),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  children: [
                    _GlassSwitchTile(
                      value: display.reduceMotion,
                      onChanged: display.setReduceMotion,
                      icon: Icons.motion_photos_off_outlined,
                      title: '减少动态效果',
                      subtitle: display.reduceMotion ? '已开启' : '已关闭',
                      onDetails: () => _showSwitchDetail(
                        listenable: display,
                        icon: Icons.motion_photos_off_outlined,
                        title: '减少动态效果',
                        description:
                            '减少页面切换、列表状态变化和部分装饰动画，降低视觉干扰，也可减轻低刷新率设备的刷新压力。',
                        value: () => display.reduceMotion,
                        onChanged: display.setReduceMotion,
                      ),
                    ),
                    const Divider(indent: 56),
                    _GlassSwitchTile(
                      value: display.predictiveBackEnabled,
                      onChanged: display.setPredictiveBackEnabled,
                      icon: Icons.swipe_left_alt_rounded,
                      title: '预见性返回',
                      subtitle: display.predictiveBackEnabled
                          ? '预见性返回'
                          : '普通返回',
                      onDetails: () => _showSwitchDetail(
                        listenable: display,
                        icon: Icons.swipe_left_alt_rounded,
                        title: '预见性返回',
                        description: '在支持的 Android 设备上，返回手势过程中会预览即将返回的页面。当前仍存在少量兼容问题；关闭后使用普通返回行为。',
                        value: () => display.predictiveBackEnabled,
                        onChanged: display.setPredictiveBackEnabled,
                        statusBuilder: (value) => value ? '预见性返回' : '普通返回',
                      ),
                    ),
                    const Divider(indent: 56),
                    _GlassSwitchTile(
                      value: display.htmlWebViewEnabled,
                      onChanged: display.setHtmlWebViewEnabled,
                      icon: Icons.language_rounded,
                      title: 'Web 阅读器',
                      subtitle: display.htmlWebViewEnabled
                          ? 'WebView'
                          : '原生 Flutter',
                      onDetails: () => _showSwitchDetail(
                        listenable: display,
                        icon: Icons.language_rounded,
                        title: 'Web 阅读器',
                        description: '开启后 HTML 使用系统 WebView 渲染，以获得更完整的网页、CSS 与 JavaScript 兼容性；关闭后使用 Flutter 原生排版。Markdown 始终使用原生渲染。',
                        value: () => display.htmlWebViewEnabled,
                        onChanged: display.setHtmlWebViewEnabled,
                        statusBuilder: (value) =>
                            value ? 'WebView' : '原生 Flutter',
                      ),
                    ),
                    const Divider(indent: 56),
                    _SettingSummaryTile(
                      icon: Icons.auto_awesome_motion_outlined,
                      title: '原生排版引擎',
                      status: display.htmlWebViewEnabled
                          ? 'Markdown'
                          : 'Markdown 与 HTML',
                      onTap: () => _showNativeEngineDetail(display),
                    ),
                  ],
                ),
              ),
            ],
            if (debugVisible) ...[
              const SliverToBoxAdapter(child: SectionLabel('调试')),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  children: [
                    _GlassSwitchTile(
                      value: debug.fpsBadgeVisible,
                      onChanged: (value) => debug.fpsBadgeVisible = value,
                      icon: Icons.speed_rounded,
                      title: '帧率显示',
                      subtitle: debug.fpsBadgeVisible ? '显示中' : '已隐藏',
                      onDetails: () => _showSwitchDetail(
                        listenable: debug,
                        icon: Icons.speed_rounded,
                        title: '帧率显示',
                        description: '在屏幕右上角显示实时渲染帧率，仅用于调试性能；关闭后不会显示帧率徽标。',
                        value: () => debug.fpsBadgeVisible,
                        onChanged: (value) => debug.fpsBadgeVisible = value,
                        statusBuilder: (value) => value ? '显示中' : '已隐藏',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!showDisplay && !showReading && !debugVisible)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('没有匹配的设置')),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
          ],
        ),
      ),
    );
  }
}

class _AboutSheet extends StatelessWidget {
  const _AboutSheet({required this.version});

  final Future<String> version;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '墨阅',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text('朴素、护眼的 Markdown、HTML 与 RSS 阅读器'),
        const SizedBox(height: 22),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.person_outline_rounded),
          title: Text('作者'),
          subtitle: Text('Magneto'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text('版本'),
          subtitle: FutureBuilder<String>(
            future: version,
            builder: (context, snapshot) {
              if (snapshot.hasData) return Text(snapshot.data!);
              if (snapshot.hasError) return const Text('无法读取版本信息');
              return const Text('正在读取版本信息…');
            },
          ),
        ),
      ],
    ),
  );
}

class _SettingDetailSheet extends StatelessWidget {
  const _SettingDetailSheet({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    this.control,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final String status;
  final Widget? control;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 22, color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Text('当前状态', style: theme.textTheme.labelLarge),
                const Spacer(),
                Flexible(
                  child: Text(
                    status,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (control != null) ...[const SizedBox(height: 8), control!],
        ],
      ),
    );
  }
}

class _FontScalePickerSheet extends StatefulWidget {
  const _FontScalePickerSheet({
    required this.scales,
    required this.initialIndex,
  });

  final List<double> scales;
  final int initialIndex;

  @override
  State<_FontScalePickerSheet> createState() => _FontScalePickerSheetState();
}

class _FontScalePickerSheetState extends State<_FontScalePickerSheet> {
  late final FixedExtentScrollController _controller;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox(
      height: 380,
      child: Column(
        children: [
          Text('软件字体大小', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '调整墨阅所有页面的界面字号。当前选择 '
              '${(widget.scales[_selectedIndex] * 100).round()}%，应用后需要重启。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListWheelScrollView.useDelegate(
              key: const ValueKey('app-font-size-wheel'),
              controller: _controller,
              itemExtent: 54,
              physics: const FixedExtentScrollPhysics(),
              diameterRatio: 1.5,
              overAndUnderCenterOpacity: 0.48,
              onSelectedItemChanged: (value) {
                if (_selectedIndex == value) return;
                setState(() => _selectedIndex = value);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: widget.scales.length,
                builder: (context, index) {
                  final selected = index == _selectedIndex;
                  final label = '${(widget.scales[index] * 100).round()}%';
                  return Center(
                    child: Semantics(
                      selected: selected,
                      label: label,
                      child: Material(
                        key: selected
                            ? const ValueKey('app-font-size-selected-option')
                            : ValueKey('app-font-size-option-$index'),
                        color: selected
                            ? colors.secondaryContainer
                            : Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        elevation: selected ? 1 : 0,
                        shadowColor: colors.shadow.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOutCubic,
                          child: SizedBox(
                            width: selected ? 156 : 112,
                            height: 44,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  label,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: selected
                                        ? colors.onSecondaryContainer
                                        : colors.onSurfaceVariant,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                if (selected) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: colors.onSecondaryContainer,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.pop(context, widget.scales[_selectedIndex]),
                child: const Text('应用'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingSummaryTile extends StatelessWidget {
  const _SettingSummaryTile({
    required this.icon,
    required this.title,
    required this.status,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey('$title-setting-summary'),
      minTileHeight: 66,
      leading: Icon(icon, size: 21),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}

class _GlassSwitchTile extends StatelessWidget {
  const _GlassSwitchTile({
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onDetails,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey('$title-switch-row-touch-area'),
      minTileHeight: 80,
      horizontalTitleGap: 8,
      leading: Icon(icon, size: 21),
      title: Semantics(
        button: true,
        label: '查看$title说明',
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onDetails,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      trailing: _GlassSwitchControl(
        touchAreaKey: ValueKey('$title-switch-touch-area'),
        value: value,
        onChanged: onChanged,
        semanticLabel: title,
      ),
    );
  }
}

class _ContrastSettingTile extends StatelessWidget {
  const _ContrastSettingTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.onDetails,
  });

  final IconData icon;
  final String title;
  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey('contrast-setting-row-touch-area'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Icon(icon, size: 21),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                Semantics(
                  button: true,
                  label: '查看$title说明',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onDetails,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      child: Row(
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const Spacer(),
                          Text(
                            '${(value * 100).round()}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _ExpandedGlassSlider(
                  touchAreaKey: const ValueKey('contrast-slider-touch-area'),
                  value: value,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassSwitchControl extends StatelessWidget {
  const _GlassSwitchControl({
    required this.touchAreaKey,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final Key touchAreaKey;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    enabled: onChanged != null,
    toggled: value,
    label: semanticLabel,
    child: SizedBox(
      key: touchAreaKey,
      width: 104,
      height: 56,
      child: IgnorePointer(
        ignoring: onChanged == null,
        child: Opacity(
          opacity: onChanged == null ? 0.45 : 1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged?.call(!value),
                ),
              ),
              ExcludeSemantics(
                child: GlassSwitch(
                  value: value,
                  onChanged: onChanged ?? (_) {},
                  useOwnLayer: true,
                  quality: GlassQuality.premium,
                  settings: moyueGlassSettings(context),
                  activeColor: Theme.of(context).colorScheme.primary,
                  semanticLabel: semanticLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ExpandedGlassSlider extends StatelessWidget {
  const _ExpandedGlassSlider({
    required this.touchAreaKey,
    required this.value,
    required this.onChanged,
  });

  final Key touchAreaKey;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: touchAreaKey,
    height: 56,
    child: LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _update(details.localPosition.dx, constraints.maxWidth),
              onHorizontalDragUpdate: (details) =>
                  _update(details.localPosition.dx, constraints.maxWidth),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 5,
            height: 46,
            child: GlassSlider(
              value: value,
              onChanged: onChanged,
              useOwnLayer: true,
              quality: GlassQuality.premium,
              settings: moyueGlassSettings(context),
            ),
          ),
        ],
      ),
    ),
  );

  void _update(double dx, double width) {
    if (width <= 0) return;
    onChanged((dx / width).clamp(0.0, 1.0));
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Card(child: Column(children: children)),
  );
}
