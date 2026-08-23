import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/features/settings/settings_page.dart';
import 'package:moyue_application/services/app_version_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  test('关于页版本由公开构建版本和内部版本代号组合', () {
    expect(
      AppVersionService.formatVersion(
        version: '1.0.1',
        internalVersion: 'Apple',
      ),
      '1.0.1(Apple)',
    );
  });

  test('内部版本未配置时只显示公开构建版本', () {
    expect(
      AppVersionService.formatVersion(version: '1.0.1', internalVersion: '  '),
      '1.0.1',
    );
  });

  testWidgets('关于页读取实际构建版本并附加内部版本', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: '墨阅',
      packageName: 'com.moyue.application',
      version: '1.0.1',
      buildNumber: '3',
      buildSignature: '',
    );
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    final key = GlobalKey<SettingsPageState>();
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: MaterialApp(home: SettingsPage(key: key)),
      ),
    );

    unawaited(key.currentState!.showAbout());
    await tester.pumpAndSettle();

    expect(
      find.text('1.0.1(${AppVersionService.internalVersion})'),
      findsOneWidget,
    );
  });
}
