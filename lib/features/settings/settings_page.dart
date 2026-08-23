import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/core/display/moyue_glass_style.dart';
import 'package:moyue_application/services/app_restart_service.dart';
import 'package:moyue_application/services/debug_service.dart';
import 'package:moyue_application/widgets/floating_page_shell.dart';
import 'package:moyue_application/widgets/expandable_glass_search.dart';
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

  Future<void> showAbout() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => const Padding(
      padding: EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '墨阅',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text('朴素、护眼的 Markdown、HTML 与 RSS 阅读器'),
          SizedBox(height: 22),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.person_outline_rounded),
            title: Text('作者'),
            subtitle: Text('Magneto'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline_rounded),
            title: Text('版本'),
            subtitle: Text('1.0.1'),
          ),
        ],
      ),
    ),
  );

  Future<void> _chooseFontSize(DisplayModeController display) async {
    final initialIndex = _nearestFontScaleIndex(display.appFontScale);
    final controller = FixedExtentScrollController(initialItem: initialIndex);
    var selectedIndex = initialIndex;
    final selected = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => SizedBox(
        height: 330,
        child: Column(
          children: [
            Text('软件字体大小', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Expanded(
              child: ListWheelScrollView.useDelegate(
                key: const ValueKey('app-font-size-wheel'),
                controller: controller,
                itemExtent: 54,
                physics: const FixedExtentScrollPhysics(),
                diameterRatio: 1.5,
                useMagnifier: true,
                magnification: 1.12,
                onSelectedItemChanged: (value) => selectedIndex = value,
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: _fontScales.length,
                  builder: (context, index) => Center(
                    child: Text(
                      '${(_fontScales[index] * 100).round()}%',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(sheetContext, _fontScales[selectedIndex]),
                  child: const Text('应用'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
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
              child: FloatingPageTitle(title: '设置', subtitle: '纸张模式 · 温和护眼'),
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
                    ),
                    const Divider(indent: 56),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.contrast_rounded),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('对比度'),
                                _ExpandedGlassSlider(
                                  touchAreaKey: const ValueKey(
                                    'contrast-slider-touch-area',
                                  ),
                                  value: display.contrast,
                                  onChanged: display.setContrast,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(indent: 56),
                    ListTile(
                      leading: const Icon(Icons.text_fields_rounded),
                      title: const Text('软件字体大小'),
                      subtitle: Text(
                        '${(display.appFontScale * 100).round()}% · 更改后自动重启',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
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
                      subtitle: '让页面切换更稳定，适合墨水屏设备',
                    ),
                    const Divider(indent: 56),
                    _GlassSwitchTile(
                      value: display.predictiveBackEnabled,
                      onChanged: display.setPredictiveBackEnabled,
                      icon: Icons.swipe_left_alt_rounded,
                      title: '预见性返回',
                      subtitle: display.predictiveBackEnabled
                          ? '已开启：返回时预览上一页（目前存在少量兼容问题）'
                          : '已关闭：使用普通返回行为',
                    ),
                    const Divider(indent: 56),
                    _GlassSwitchTile(
                      value: display.htmlWebViewEnabled,
                      onChanged: display.setHtmlWebViewEnabled,
                      icon: Icons.language_rounded,
                      title: 'HTML WebView 阅读器',
                      subtitle: display.htmlWebViewEnabled
                          ? '已开启：使用系统网页引擎并运行页面脚本'
                          : '已关闭：使用原生 Flutter 排版引擎',
                    ),
                    const Divider(indent: 56),
                    const ListTile(
                      leading: Icon(Icons.auto_awesome_motion_outlined),
                      title: Text('原生排版引擎'),
                      subtitle: Text('Markdown 始终原生；HTML 可在上方切换'),
                      trailing: Icon(Icons.verified_rounded),
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
                      subtitle: '在屏幕右上角实时刷新渲染帧率',
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

class _GlassSwitchTile extends StatelessWidget {
  const _GlassSwitchTile({
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey('$title-switch-row-touch-area'),
    minTileHeight: 80,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    onTap: onChanged == null ? null : () => onChanged!(!value),
    trailing: Semantics(
      enabled: onChanged != null,
      toggled: value,
      label: title,
      child: SizedBox(
        key: ValueKey('$title-switch-touch-area'),
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
                    semanticLabel: title,
                  ),
                ),
              ],
            ),
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
    height: 72,
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
            top: 13,
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
