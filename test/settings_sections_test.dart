import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/features/settings/settings_page.dart';
import 'package:moyue_application/widgets/floating_page_shell.dart';
import 'package:moyue_application/widgets/section_label.dart';

void main() {
  testWidgets('设置分组按使用场景排列，搜索仍可找到移动后的选项', (tester) async {
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );
    List<String> sections() => tester
        .widget<CustomScrollView>(
          find.byKey(const PageStorageKey('settings-scroll')),
        )
        .slivers
        .whereType<SliverToBoxAdapter>()
        .map((sliver) => sliver.child)
        .whereType<SectionLabel>()
        .map((header) => header.label)
        .toList();

    expect(sections(), ['外观与纸面', '文字与字号', '阅读与内容', '交互与语言', '数据与存储']);
    for (final entry in {
      '字体': '文字与字号',
      '全文': '阅读与内容',
      'HTML': '阅读与内容',
      '动画': '交互与语言',
      '缓存': '数据与存储',
    }.entries) {
      tester
          .widget<FloatingPageShell>(find.byType(FloatingPageShell))
          .onSearch!(entry.key);
      await tester.pumpAndSettle();
      expect(sections(), [entry.value]);
    }
    tester.widget<FloatingPageShell>(find.byType(FloatingPageShell)).onSearch!(
      '不存在的设置',
    );
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的设置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
