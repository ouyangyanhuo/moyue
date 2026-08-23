import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:moyue_application/services/folder_bundle_picker_base.dart';

FolderBundlePicker createFolderBundlePicker() => _WebFolderBundlePicker();

class _WebFolderBundlePicker implements FolderBundlePicker {
  @override
  Future<FolderBundle?> pick() async {
    final result = await FilePicker.pickFiles();
    if (result.isEmpty) return null;
    final archive = Archive();
    for (final file in result) {
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile.bytes(file.name, bytes));
    }
    return FolderBundle(
      name: 'Web 文件夹',
      zipBytes: ZipEncoder().encodeBytes(archive),
    );
  }
}
