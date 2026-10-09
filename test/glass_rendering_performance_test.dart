import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/src/renderer/internal/geometry_raster_cache.dart';
import 'package:moyue_application/core/navigation/moyue_page_route.dart';
import 'package:moyue_application/core/display/display_preferences.dart';
import 'package:moyue_application/features/editor/editor_page.dart';
import 'package:moyue_application/features/reader/reader_detail_page.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/widgets/moyue_glass_icon_button.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _Pops extends NavigatorObserver {
  final popped = <Route<dynamic>>[];
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      popped.add(route);
}

MoyueMaterialPageRoute<void> _route(
  Widget child, {
  bool reduceMotion = false,
}) => MoyueMaterialPageRoute<void>(
  builder: (_) => child,
  predictiveBackEnabled: true,
  reduceMotion: reduceMotion,
  inkMode: false,
  allowSnapshotting: false,
);

Future<void> _gesture(
  WidgetTester tester,
  String method, [
  double? progress,
]) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(
      MethodCall(
        method,
        progress == null
            ? null
            : <String, dynamic>{
                'touchOffset': <double>[5 + progress * 300, 300],
                'progress': progress,
                'swipeEdge': 0,
              },
      ),
    ),
    (_) {},
  );
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('120 帧重复布局只需要一份相同的几何纹理', () {
    final cache = GeometryRasterCache();
    final shape = Object();
    final geometry = Object();
    const bounds = Rect.fromLTWH(0, 0, 44, 44);
    var builds = 0;
    for (var frame = 0; frame < 120; frame++) {
      final entries = [(shape, geometry, Matrix4.identity())];
      if (!cache.matches(entries, bounds, 3)) {
        cache.record(entries, bounds, 3);
        builds++;
      }
    }
    expect(builds, 1);
  });

  test('尺寸、DPR、形状、顺序和亚像素形变均使缓存失效', () {
    final cache = GeometryRasterCache();
    final a = Object(), b = Object(), geometry = Object();
    final matrix = Matrix4.identity();
    final entries = [(a, geometry, matrix), (b, geometry, Matrix4.identity())];
    const bounds = Rect.fromLTWH(0, 0, 44, 44);
    cache.record(entries, bounds, 3);
    expect(
      cache.matches(entries, const Rect.fromLTWH(0, 0, 45, 44), 3),
      isFalse,
    );
    expect(cache.matches(entries, bounds, 2), isFalse);
    expect(cache.matches(entries.reversed.toList(), bounds, 3), isFalse);
    expect(cache.matches(entries.take(1).toList(), bounds, 3), isFalse);
    expect(
      cache.matches([(a, Object(), matrix), entries.last], bounds, 3),
      isFalse,
    );
    matrix.storage[12] = 0.001;
    expect(cache.matches(entries, bounds, 3), isFalse);
    matrix.storage[12] = 0;
    expect(cache.matches(entries, bounds, 3), isTrue);
    cache.clear();
    expect(cache.matches(entries, bounds, 3), isFalse);
  });

  test('premium shader 与补丁前逐字节一致', () {
    const hashes = {
      'liquid_glass_final_render.frag':
          'aaa8ff95e08623323e3f94aa23ce1d10088ee78de81acde0fa0744d2c2b95f9d',
      'liquid_glass_geometry_blended.frag':
          'c1c3882447442b1f0bbf0feb21d63e7e335c1c5f60565724822bed5aa7538103',
      'interactive_indicator.frag':
          'f916bb44681b6eeeac2ded0e8bec71d92202db75a17f4bfd8c06495ffb27780b',
    };
    for (final entry in hashes.entries) {
      expect(
        sha256
            .convert(
              File('third_party/liquid_glass_widgets/shaders/${entry.key}')
                  .readAsBytesSync(),
            )
            .toString(),
        entry.value,
      );
    }
  });

  testWidgets('页面进入与返回均不会驱动底层页面的第二套动画', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('home')),
      ),
    );
    final lower = _route(const Scaffold(body: Text('lower')));
    navigator.currentState!.push(lower);
    await tester.pumpAndSettle();
    final upper = _route(const Scaffold(body: Text('upper')));
    navigator.currentState!.push(upper);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(lower.secondaryAnimation!.value, 0);
    }
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(lower.secondaryAnimation!.value, 0);
    }
    await tester.pumpAndSettle();
    expect(lower.isCurrent, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('预测性返回可取消、可提交，底层页面始终静止', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final observer = _Pops();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [observer],
        theme: ThemeData(platform: TargetPlatform.android),
        home: const Scaffold(body: Text('home')),
      ),
    );
    final lower = _route(const Scaffold(body: Text('lower')));
    navigator.currentState!.push(lower);
    await tester.pumpAndSettle();
    final upper = _route(const Scaffold(body: Text('upper')));
    navigator.currentState!.push(upper);
    await tester.pumpAndSettle();
    for (final commit in [false, true]) {
      await _gesture(tester, 'startBackGesture', 0);
      expect(upper.popGestureInProgress, isTrue);
      await _gesture(tester, 'updateBackGestureProgress', 0.4);
      expect(lower.secondaryAnimation!.value, 0);
      await _gesture(
        tester,
        commit ? 'commitBackGesture' : 'cancelBackGesture',
      );
      await tester.pumpAndSettle();
      expect(observer.popped.length, commit ? 1 : 0);
      expect(commit ? lower.isCurrent : upper.isCurrent, isTrue);
    }
    expect(tester.takeException(), isNull);
  });

  for (final editor in [false, true]) {
    testWidgets('${editor ? '编辑器' : '阅读器'}快速重复返回只退出一层', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final observer = _Pops();
      final display = MoyueDisplayPreferences();
      addTearDown(display.dispose);
      final doc = ReadingDocument(
        id: 'back-test',
        title: 'Test',
        content: '# Text',
        kind: DocumentKind.markdown,
        updatedAt: DateTime(2026),
      );
      await tester.pumpWidget(
        DisplayPreferencesScope(
          controller: display,
          child: MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [observer],
            home: const Scaffold(body: Text('home')),
          ),
        ),
      );
      final lower = _route(const Scaffold(body: Text('lower')));
      navigator.currentState!.push(lower);
      await tester.pumpAndSettle();
      final upper = _route(
        editor
            ? MarkdownEditorPage(document: doc)
            : ReaderDetailPage(document: doc),
      );
      navigator.currentState!.push(upper);
      await tester.pumpAndSettle();
      final back = tester
          .widget<MoyueGlassIconButton>(find.byType(MoyueGlassIconButton).first)
          .onPressed!;
      back();
      back();
      await tester.pump(const Duration(milliseconds: 20));
      back(); // The outgoing widget is still mounted during reverse animation.
      await tester.pumpAndSettle();
      expect(observer.popped, [upper]);
      expect(lower.isCurrent, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('减少动态效果时仍正常返回但没有转场时长', (tester) async {
    final route = _route(const Text('page'), reduceMotion: true);
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
    route.dispose();
  });
}
