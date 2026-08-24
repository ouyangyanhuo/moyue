import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/services/incoming_file_service.dart';

void main() {
  test('外部导入只接受 Markdown、HTML、ZIP 和 moyue', () {
    expect(IncomingFileService.supportsFileName('笔记.MD'), isTrue);
    expect(IncomingFileService.supportsFileName('page.html'), isTrue);
    expect(IncomingFileService.supportsFileName('archive.zip'), isTrue);
    expect(IncomingFileService.supportsFileName('book.moyue'), isTrue);
    expect(IncomingFileService.supportsFileName('script.js'), isFalse);
    expect(IncomingFileService.supportsFileName('image.png'), isFalse);
  });

  test('Android 声明并桥接系统打开与分享文件', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/moyue/application/MainActivity.kt',
    ).readAsStringSync();

    expect(manifest, contains('android.intent.action.VIEW'));
    expect(manifest, contains('android.intent.action.SEND'));
    expect(manifest, contains('android.intent.action.SEND_MULTIPLE'));
    for (final mime in const [
      'text/markdown',
      'text/html',
      'application/zip',
      'application/x-moyue',
    ]) {
      expect(manifest, contains(mime));
    }
    expect(activity, contains('com.moyue.application/incoming_files'));
    expect(activity, contains('captureIncomingIntent(intent)'));
    expect(activity, contains('extensionForMimeType'));
    expect(activity, contains('takePendingFiles'));
  });
}
