import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/widgets/stable_reader_image.dart';

void main() {
  for (final failure in ['missing', 'throws', 'corrupt']) {
    testWidgets('图片 $failure 显示缺失占位且缓存失败结果', (tester) async {
      final cache = ReaderImageSessionCache();
      addTearDown(cache.clear);
      var reads = 0;
      Widget image() => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 80,
              child: StableReaderImage(
                cacheKey: failure,
                sessionCache: cache,
                loader: () async {
                  reads++;
                  if (failure == 'throws')
                    throw StateError('missing private/path.png');
                  return failure == 'missing'
                      ? null
                      : Uint8List.fromList([1, 2, 3]);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(image());
      await tester.pumpAndSettle();
      expect(find.text('引用的资源不存在'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(image());
      await tester.pumpAndSettle();
      expect(reads, 1);
      expect(find.text('引用的资源不存在'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('阅读器图片在最终尺寸的占位符上显示', (tester) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
      'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              child: StableReaderImage(
                cacheKey: 'one-pixel',
                loader: () async => bytes,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final placeholder = find.byKey(
      const ValueKey('stable-reader-image-placeholder'),
    );
    final content = find.byKey(const ValueKey('stable-reader-image-content'));
    expect(placeholder, findsOneWidget);
    expect(content, findsOneWidget);
    expect(tester.getSize(placeholder), tester.getSize(content));
    expect(tester.widget<AnimatedOpacity>(content).opacity, 1);
  });

  testWidgets('图片只在进入视口后加载且返回时不会再次读取', (tester) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
      'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final controller = ScrollController();
    final cache = ReaderImageSessionCache();
    var loadCount = 0;
    addTearDown(controller.dispose);
    addTearDown(cache.clear);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: controller,
            scrollCacheExtent: const ScrollCacheExtent.pixels(0),
            children: [
              const SizedBox(height: 900),
              StableReaderImage(
                key: const ValueKey('lazy-reader-image'),
                cacheKey: 'lazy-image',
                sessionCache: cache,
                width: 120,
                height: 80,
                loader: () async {
                  loadCount += 1;
                  return bytes;
                },
              ),
              const SizedBox(height: 900),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(loadCount, 0);
    expect(cache.length, 0);

    controller.jumpTo(760);
    await tester.pumpAndSettle();
    expect(loadCount, 1);
    expect(cache.length, 1);
    expect(
      find.byKey(const ValueKey('stable-reader-image-content')),
      findsOneWidget,
    );

    controller.jumpTo(0);
    await tester.pump();
    controller.jumpTo(760);
    await tester.pumpAndSettle();
    expect(loadCount, 1);
    expect(
      find.byKey(const ValueKey('stable-reader-image-content')),
      findsOneWidget,
    );
  });

  testWidgets('已阅图片即使 Widget 被回收也会从阅读会话缓存直接恢复', (tester) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
      'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final cache = ReaderImageSessionCache();
    final visible = ValueNotifier(true);
    var loadCount = 0;
    addTearDown(cache.clear);
    addTearDown(visible.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (context, show, _) => show
                ? StableReaderImage(
                    cacheKey: 'recreated-image',
                    sessionCache: cache,
                    width: 120,
                    height: 80,
                    loader: () async {
                      loadCount += 1;
                      return bytes;
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(loadCount, 1);

    visible.value = false;
    await tester.pump();
    visible.value = true;
    await tester.pump();

    expect(loadCount, 1);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('stable-reader-image-content')),
          )
          .opacity,
      1,
    );
  });
}
