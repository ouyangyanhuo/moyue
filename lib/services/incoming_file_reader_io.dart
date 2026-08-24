import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readIncomingFile(String path) => File(path).readAsBytes();

Future<void> deleteIncomingFile(String path) async {
  try {
    await File(path).delete();
  } on FileSystemException {
    // Cache files are best-effort cleanup and never the source document.
  }
}
