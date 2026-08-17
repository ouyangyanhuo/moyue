import 'dart:convert';
import 'dart:typed_data';

import 'package:charset/charset.dart';

String decodeImportedText(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xef &&
      bytes[1] == 0xbb &&
      bytes[2] == 0xbf) {
    return utf8.decode(bytes.sublist(3));
  }
  if (bytes.length >= 2 &&
      ((bytes[0] == 0xff && bytes[1] == 0xfe) ||
          (bytes[0] == 0xfe && bytes[1] == 0xff))) {
    return utf16.decode(bytes);
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return gbk.decode(bytes);
  }
}

String decodeArchiveFileName(String value) {
  final units = value.codeUnits;
  if (!units.any((unit) => unit > 0x7f) || units.any((unit) => unit > 0xff)) {
    return value;
  }
  try {
    return gbk.decode(units);
  } on Object {
    return value;
  }
}
