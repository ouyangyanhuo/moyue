import 'package:archive/archive.dart';

void inflatePackageEntry(InputStream input, OutputStream output) =>
    const ZLibDecoderWeb().decodeStream(input, output, raw: true);
