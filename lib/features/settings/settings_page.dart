import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/widgets/page_heading.dart';
import 'package:moyue_application/widgets/section_label.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final display = DisplayPreferencesScope.of(context);
    final query = _query.trim();
    final showDisplay = query.isEmpty || '显示墨模式对比度护眼'.contains(query);
    final showReading = query.isEmpty || '阅读动画翻页动效'.contains(query);

    return CustomScrollView(
      key: const PageStorageKey('settings-scroll'),
      slivers: [
        SliverToBoxAdapter(
          child: PageHeading(
            title: '设置',
            subtitle: '纸张模式 · 温和护眼',
            searchHint: '搜索设置',
            onSearch: (value) => setState(() => _query = value),
          ),
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
                const ListTile(
                  leading: Icon(Icons.auto_awesome_motion_outlined),
                  title: Text('原生排版引擎'),
                  subtitle: Text('Markdown 与 HTML 均由 Flutter 组件渲染'),
                  trailing: Icon(Icons.verified_rounded),
                ),
              ],
            ),
          ),
        ],
        if (!showDisplay && !showReading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('没有匹配的设置')),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
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
                    quality: GlassQuality.standard,
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
              quality: GlassQuality.standard,
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
