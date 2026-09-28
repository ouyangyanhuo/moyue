import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';

void inflatePackageEntry(InputStream input, OutputStream output) {
  final decoder = ZLibCodec(raw: true).decoder
      .startChunkedConversion(_OutputSink(output));
  while (!input.isEOS) {
    decoder.add(input.readBytes(math.min(16384, input.length)).toUint8List());
  }
  decoder.close();
}

class _OutputSink implements Sink<List<int>> {
  _OutputSink(this.output);
  final OutputStream output;
  @override
  void add(List<int> data) => output.writeBytes(data);
  @override
  void close() => output.flush();
}
