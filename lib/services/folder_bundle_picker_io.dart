import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:moyue_application/services/folder_bundle_picker_base.dart';
import 'package:path/path.dart' as p;

FolderBundlePicker createFolderBundlePicker() => _IoFolderBundlePicker();

class _IoFolderBundlePicker implements FolderBundlePicker {
  @override
  Future<FolderBundle?> pick() async {
    final selected = await FilePicker.getDirectoryPath();
    if (selected == null) return null;
    final root = Directory(selected);
    final archive = Archive();
    var total = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final bytes = await entity.readAsBytes();
      total += bytes.length;
      if (total > 64 * 1024 * 1024) {
        throw const FormatException('文件夹总大小不能超过 64 MB');
      }
      final relative = p
          .relative(entity.path, from: root.path)
          .replaceAll('\\', '/');
      archive.addFile(ArchiveFile.bytes(relative, bytes));
    }
    return FolderBundle(
      name: p.basename(root.path),
      zipBytes: ZipEncoder().encodeBytes(archive),
    );
  }
}
