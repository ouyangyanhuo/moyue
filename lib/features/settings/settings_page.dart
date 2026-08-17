import 'package:flutter/material.dart';
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
    final isInk = display.mode == ReadingDisplayMode.ink;
    final query = _query.trim();
    final showDisplay = query.isEmpty || '显示墨模式对比度护眼Liquid透明度'.contains(query);
    final showReading = query.isEmpty || '阅读动画翻页动效'.contains(query);

    return CustomScrollView(
      key: const PageStorageKey('settings-scroll'),
      slivers: [
        SliverToBoxAdapter(
          child: PageHeading(
            title: '设置',
            subtitle: isInk ? '墨模式已开启' : '纸张模式 · 温和护眼',
            searchHint: '搜索设置',
            onSearch: (value) => setState(() => _query = value),
          ),
        ),
        if (showDisplay) ...[
          const SliverToBoxAdapter(child: SectionLabel('显示')),
          SliverToBoxAdapter(
            child: _SettingsCard(
              children: [
                SwitchListTile.adaptive(
                  value: isInk,
                  onChanged: (value) => display.setMode(
                    value ? ReadingDisplayMode.ink : ReadingDisplayMode.paper,
                  ),
                  secondary: const Icon(Icons.water_drop_outlined),
                  title: const Text('墨模式'),
                  subtitle: const Text('降低色彩与动效，模拟电子墨水阅读体验'),
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
                            Slider(
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.opacity_rounded),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Liquid 透明度  ${(display.glassOpacity * 100).round()}%',
                            ),
                            Slider(
                              value: display.glassOpacity,
                              min: 0,
                              max: 1,
                              onChanged: display.setGlassOpacity,
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
                SwitchListTile.adaptive(
                  value: display.reduceMotion,
                  onChanged: display.setReduceMotion,
                  secondary: const Icon(Icons.motion_photos_off_outlined),
                  title: const Text('减少动态效果'),
                  subtitle: const Text('让页面切换更稳定，适合墨水屏设备'),
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Card(child: Column(children: children)),
  );
}
