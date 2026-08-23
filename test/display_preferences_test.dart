import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  test('HTML WebView 开关会持久化并在下次启动恢复', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final first = MoyueDisplayPreferences();
    first.setHtmlWebViewEnabled(true);
    await Future<void>.delayed(Duration.zero);

    final restored = MoyueDisplayPreferences();
    await restored.load();

    expect(restored.htmlWebViewEnabled, isTrue);
    first.dispose();
    restored.dispose();
  });
}
