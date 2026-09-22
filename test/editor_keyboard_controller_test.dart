import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/features/editor/editor_keyboard_controller.dart';
import 'package:moyue_application/features/editor/editor_page.dart';

const _system = MethodChannel('com.moyue.application/system');
const _events = MethodChannel('com.moyue.application/editor_keyboard');
const _codec = StandardMethodCodec();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var cancellations = 0;

  setUp(() {
    cancellations = 0;
    messenger.setMockMethodCallHandler(_system, (call) async {
      expect(call.method, 'editorKeyboardEventsSupported');
      return true;
    });
    messenger.setMockMethodCallHandler(_events, (call) async {
      if (call.method == 'cancel') cancellations++;
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(_system, null);
    messenger.setMockMethodCallHandler(_events, null);
  });

  Future<void> emit(String phase, [double bottom = 0]) async {
    await messenger.handlePlatformMessage(
      _events.name,
      _codec.encodeSuccessEnvelope({'phase': phase, 'bottom': bottom}),
      (_) {},
    );
  }

  testWidgets('原生键盘事件无采样延迟，逐帧 metrics 不通知编辑器', (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final controller = EditorKeyboardController(tester.view);
    var changes = 0;
    controller.addListener(() => changes++);
    await tester.pump();

    await emit('changing');
    expect(controller.animating, isTrue);
    expect(changes, 1);
    for (var i = 1; i <= 40; i++) {
      tester.view.viewInsets = FakeViewPadding(bottom: i * 15);
      await tester.pump(const Duration(milliseconds: 8));
    }
    expect(changes, 1, reason: '平台动画的40帧不应触发业务状态更新');
    expect(controller.inset, 0);
    await emit('settled', 600);
    expect(controller.inset, 300);
    expect(controller.animating, isFalse);
    expect(changes, 2, reason: '收到结束事件后立即提交，不再等待80ms和三次采样');
    await emit('settled', 600);
    expect(changes, 2, reason: '相同结束事件去重');

    await emit('changing');
    expect(controller.inset, 300, reason: '收起动画期间不重排正文');
    await emit('settled');
    expect(controller.inset, 0);
    controller.dispose();
    await tester.pump();
    expect(cancellations, 1);
    await emit('settled', 600);
    expect(changes, 4, reason: '离开页面取消原生订阅');
  });

  testWidgets('原生事件驱动工具栏，固定画布隔离键盘帧并保留旋转响应', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final display = MoyueDisplayPreferences();
    addTearDown(display.dispose);
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: display,
        child: const MaterialApp(home: MarkdownEditorPage()),
      ),
    );
    await tester.pump();
    final body = find.byType(TextField).last;
    final surface = find.byKey(const ValueKey('editor-writing-surface'));
    final dock = find.byKey(const ValueKey('keyboard-format-dock'));
    final originalBounds = tester.getRect(surface);
    await tester.tap(body);
    await tester.pump();
    final fieldBeforeAnimation = tester.widget<TextField>(body);
    await emit('changing');
    for (var i = 1; i <= 20; i++) {
      tester.view.viewInsets = FakeViewPadding(bottom: i * 15);
      await tester.pump(const Duration(milliseconds: 8));
      expect(tester.widget<TextField>(body), same(fieldBeforeAnimation));
      expect(tester.getRect(surface), originalBounds);
      expect(dock, findsNothing);
    }
    await emit('settled', 300);
    await tester.pump();
    expect(dock, findsOneWidget);
    expect(tester.getBottomLeft(dock).dy, 622);
    expect(tester.getRect(surface), originalBounds);

    // Closing via the system back button keeps TextField focus, but hides the dock.
    await emit('changing');
    await tester.pump();
    expect(dock, findsNothing);
    expect(tester.widget<TextField>(body).focusNode!.hasFocus, isTrue);
    final fieldDuringClose = tester.widget<TextField>(body);
    tester.view.viewInsets = const FakeViewPadding(bottom: 100);
    await tester.pump();
    expect(tester.widget<TextField>(body), same(fieldDuringClose));
    tester.view.viewInsets = const FakeViewPadding();
    await emit('settled');
    await tester.pump();
    expect(dock, findsNothing);
    expect(tester.getRect(surface), originalBounds);

    // Already-open keyboards, focus changes and keyboard height changes need no timer.
    await emit('settled', 250);
    await tester.pump();
    expect(tester.getBottomLeft(dock).dy, 672);
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(dock, findsNothing);
    await tester.tap(body);
    await tester.pump();
    expect(dock, findsOneWidget);

    tester.view.physicalSize = const Size(932, 430);
    await emit('settled', 160);
    await tester.pump();
    expect(tester.getRect(surface).width, 932);
    expect(tester.getRect(surface).bottom, 418);
    expect(tester.getBottomLeft(dock).dy, 260);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(cancellations, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('不支持原生事件时仅在静止后更新且不持续轮询', (tester) async {
    messenger.setMockMethodCallHandler(_system, (call) async => false);
    addTearDown(tester.view.resetViewInsets);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = EditorKeyboardController(tester.view);
    await tester.pump();
    var changes = 0;
    controller.addListener(() => changes++);
    for (var i = 1; i <= 30; i++) {
      tester.view.viewInsets = FakeViewPadding(bottom: i * 10);
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(changes, 0);
    await tester.pump(const Duration(milliseconds: 80));
    expect(changes, 1);
    expect(controller.inset, 300);
    await tester.pump(const Duration(seconds: 2));
    expect(changes, 1);
    tester.view.viewInsets = const FakeViewPadding();
    expect(controller.animating, isTrue);
    controller.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(changes, 2, reason: '销毁取消未完成的兼容计时器');
  });
}
