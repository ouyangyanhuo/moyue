import 'dart:typed_data';

class FolderBundle {
  const FolderBundle({required this.name, required this.zipBytes});
  final String name;
  final Uint8List zipBytes;
}

abstract interface class FolderBundlePicker {
  Future<FolderBundle?> pick();
}
