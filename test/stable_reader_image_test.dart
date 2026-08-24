import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/widgets/stable_reader_image.dart';

void main() {
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
}
