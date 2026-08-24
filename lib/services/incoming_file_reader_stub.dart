import 'dart:typed_data';

Future<Uint8List> readIncomingFile(String path) =>
    Future.error(UnsupportedError('Incoming files are unavailable'));

Future<void> deleteIncomingFile(String path) async {}
