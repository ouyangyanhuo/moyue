import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/document_package_service.dart';
import 'package:share_plus/share_plus.dart';

class SystemShareService {
  const SystemShareService._();

  @visibleForTesting
  static Future<ShareResult> Function(ShareParams params)? debugShareOverride;

  static Future<ShareResult> shareDocument(
    BuildContext context,
    ReadingDocument document,
  ) {
    final extension = document.kind.extension;
    final safeTitle = document.title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    final baseName = safeTitle.isEmpty ? document.id : safeTitle;
    final fileName = baseName.toLowerCase().endsWith('.$extension')
        ? baseName
        : '$baseName.$extension';
    return shareBytes(
      context,
      bytes: Uint8List.fromList(utf8.encode(document.content)),
      fileName: fileName,
      mimeType: document.kind == DocumentKind.html
          ? 'text/html'
          : 'text/markdown',
    );
  }

  static Future<ShareResult> shareSelection(
    BuildContext context, {
    List<ReadingDocument> documents = const [],
    List<MoyueExport> folders = const [],
  }) {
    final files = <({Uint8List bytes, String name, String mimeType})>[];
    for (final document in documents) {
      final extension = document.kind.extension;
      final safeTitle = _safeName(document.title, fallback: document.id);
      files.add((
        bytes: Uint8List.fromList(utf8.encode(document.content)),
        name: safeTitle.toLowerCase().endsWith('.$extension')
            ? safeTitle
            : '$safeTitle.$extension',
        mimeType: document.kind == DocumentKind.html
            ? 'text/html'
            : 'text/markdown',
      ));
    }
    for (final folder in folders) {
      files.add((
        bytes: folder.bytes,
        name: folder.fileName,
        mimeType: 'application/vnd.moyue.package+zip',
      ));
    }
    if (files.isEmpty) throw StateError('没有可分享的项目');
    return _share(
      ShareParams(
        files: [
          for (final file in files)
            XFile.fromData(file.bytes, mimeType: file.mimeType),
        ],
        fileNameOverrides: [for (final file in files) file.name],
        sharePositionOrigin: _shareOrigin(context),
      ),
    );
  }

  static Future<ShareResult> shareMoyue(
    BuildContext context,
    MoyueExport export,
  ) => shareBytes(
    context,
    bytes: export.bytes,
    fileName: export.fileName,
    mimeType: 'application/vnd.moyue.package+zip',
  );

  static Future<ShareResult> shareText(
    BuildContext context, {
    required String text,
    required String subject,
  }) => _share(
    ShareParams(
      text: text,
      subject: subject,
      sharePositionOrigin: _shareOrigin(context),
    ),
  );

  static Future<ShareResult> shareMarkdownImage(
    BuildContext context, {
    required Uint8List bytes,
    required String title,
  }) {
    var baseName = _safeName(title, fallback: 'moyue');
    if (baseName.toLowerCase().endsWith('.md')) {
      baseName = baseName.substring(0, baseName.length - 3);
    }
    return shareBytes(
      context,
      bytes: bytes,
      fileName: '$baseName.png',
      mimeType: 'image/png',
    );
  }

  static Future<ShareResult> shareBytes(
    BuildContext context, {
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) {
    return _share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType)],
        fileNameOverrides: [fileName],
        sharePositionOrigin: _shareOrigin(context),
      ),
    );
  }

  static Rect? _shareOrigin(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  static Future<ShareResult> _share(ShareParams params) {
    final override = debugShareOverride;
    return override == null
        ? SharePlus.instance.share(params)
        : override(params);
  }

  static String _safeName(String value, {required String fallback}) {
    final safe = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return safe.isEmpty ? fallback : safe;
  }
}
