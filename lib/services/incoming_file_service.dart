import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:moyue_application/core/files/document_import_policy.dart';
import 'package:moyue_application/services/incoming_file_reader.dart';
import 'package:moyue_application/services/moyue_storage_service.dart';

class IncomingFileEvent {
  const IncomingFileEvent({
    required this.revision,
    required this.fileName,
    required this.succeeded,
    this.error,
  });

  final int revision;
  final String fileName;
  final bool succeeded;
  final String? error;
}

/// Receives files staged by the Android share/open-with intent bridge.
class IncomingFileService extends ChangeNotifier {
  IncomingFileService._();

  static final instance = IncomingFileService._();
  static const _channel = MethodChannel('com.moyue.application/incoming_files');
  static const _documentLimit = 8 * 1024 * 1024;
  static const _packageLimit = 128 * 1024 * 1024;
  static const supportedExtensions = DocumentImportPolicy.supportedExtensions;

  bool _initialized = false;
  bool _draining = false;
  bool _drainAgain = false;
  int _revision = 0;
  IncomingFileEvent? _latestEvent;

  IncomingFileEvent? get latestEvent => _latestEvent;

  @visibleForTesting
  static bool supportsFileName(String fileName) =>
      DocumentImportPolicy.supportsFileName(fileName);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'incomingFilesAvailable') await _drain();
    });
    await _drain();
  }

  Future<void> _drain() async {
    if (_draining) {
      _drainAgain = true;
      return;
    }
    _draining = true;
    try {
      do {
        _drainAgain = false;
        final files = await _takePendingFiles();
        for (final file in files) {
          await _import(file);
        }
      } while (_drainAgain);
    } on MissingPluginException {
      // Non-Android platforms have no incoming intent bridge.
    } on PlatformException {
      // A failed platform query must not prevent normal app startup.
    } finally {
      _draining = false;
    }
  }

  Future<List<({String name, String path})>> _takePendingFiles() async {
    final values = await _channel.invokeListMethod<Object?>('takePendingFiles');
    if (values == null) return const [];
    final result = <({String name, String path})>[];
    for (final value in values) {
      if (value is! Map) continue;
      final name = value['name'];
      final path = value['path'];
      if (name is String &&
          name.isNotEmpty &&
          path is String &&
          path.isNotEmpty) {
        result.add((name: name, path: path));
      }
    }
    return result;
  }

  Future<void> _import(({String name, String path}) file) async {
    try {
      if (!supportsFileName(file.name)) {
        throw const FormatException('仅支持 .zip、.moyue、.md、.html 或 .htm 文件');
      }
      final bytes = await readIncomingFile(file.path);
      final extension = _extension(file.name);
      final limit = DocumentImportPolicy.textExtensions.contains(extension)
          ? _documentLimit
          : _packageLimit;
      if (bytes.length > limit) {
        final megabytes = limit ~/ (1024 * 1024);
        throw FormatException('文件不能超过 $megabytes MB');
      }
      await MoyueStorageService.instance.importDocumentPackage(
        fileName: file.name,
        bytes: bytes,
      );
      _emit(fileName: file.name, succeeded: true);
    } on Object catch (error) {
      _emit(fileName: file.name, succeeded: false, error: '$error');
    } finally {
      await deleteIncomingFile(file.path);
    }
  }

  void _emit({
    required String fileName,
    required bool succeeded,
    String? error,
  }) {
    _latestEvent = IncomingFileEvent(
      revision: ++_revision,
      fileName: fileName,
      succeeded: succeeded,
      error: error,
    );
    notifyListeners();
  }

  static String _extension(String fileName) =>
      DocumentImportPolicy.extensionOf(fileName);
}
