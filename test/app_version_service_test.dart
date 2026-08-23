import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/features/settings/settings_page.dart';
import 'package:moyue_application/services/app_version_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _expectedBuildInternalVersion = String.fromEnvironment(
  'MOYUE_EXPECTED_INTERNAL_VERSION',
);

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

  test('工作流传入的内部版本会成为应用的编译期内部版本', () {
    expect(AppVersionService.internalVersion, _expectedBuildInternalVersion);
  }, skip: _expectedBuildInternalVersion.isEmpty ? '仅在构建工作流传入校验值时运行' : false);

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

    final expectedVersion = AppVersionService.formatVersion(
      version: '1.0.1',
      internalVersion: AppVersionService.internalVersion.trim().isEmpty
          ? '3'
          : AppVersionService.internalVersion,
    );
    expect(find.text(expectedVersion), findsOneWidget);
  });
}
