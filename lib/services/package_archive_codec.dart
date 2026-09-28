import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:moyue_application/services/text_decoder.dart';
import 'package:path/path.dart' as p;

import 'archive_inflate_stub.dart'
    if (dart.library.io) 'archive_inflate_io.dart';

class PackageArchiveLimits {
  const PackageArchiveLimits({
    this.compressedBytes = 128 * 1024 * 1024,
    this.totalBytes = 256 * 1024 * 1024,
    this.fileBytes = 64 * 1024 * 1024,
    this.entries = 4096,
  });
  final int compressedBytes, totalBytes, fileBytes, entries;
}

class DecodedPackageArchive {
  const DecodedPackageArchive(this.files, this.hashes);
  final Map<String, Uint8List> files;
  final Map<String, String> hashes;
}

/// Native platforms run codec/CRC/hash work in an isolate. Web uses compute's
/// supported same-event-loop fallback; it does not claim native parallelism.
class PackageArchiveCodec {
  static Future<DecodedPackageArchive> decode(
    Uint8List bytes, {
    PackageArchiveLimits limits = const PackageArchiveLimits(),
  }) async {
    if (bytes.length > limits.compressedBytes) {
      throw const FormatException('压缩包超过大小限制');
    }
    return compute(_decode, (
      bytes,
      limits,
    ), debugLabel: 'moyue-package-decode');
  }

  static Future<Uint8List> encode(
    Map<String, Uint8List> files, {
    PackageArchiveLimits limits = const PackageArchiveLimits(),
  }) => compute(_encode, (files, limits), debugLabel: 'moyue-package-encode');

  static Future<String> hash(Uint8List bytes) => bytes.length < 256 * 1024
      ? Future.value(_hash(bytes))
      : compute(_hash, bytes, debugLabel: 'moyue-file-hash');

  static String _hash(Uint8List bytes) => sha256.convert(bytes).toString();

  static String safePath(String value) {
    final path = value.replaceAll('\\', '/');
    if (path.contains('\u0000') ||
        path.contains(':') ||
        path.startsWith('/') ||
        path.split('/').contains('..')) {
      throw const FormatException('压缩包包含不安全路径');
    }
    final normalized = p.posix.normalize(path);
    if (normalized == '.' || normalized.isEmpty) {
      throw const FormatException('压缩包包含不安全路径');
    }
    return normalized;
  }

  static bool allowedPath(String path) =>
      path == 'meta.json' ||
      const {
        'md',
        'html',
        'htm',
        'css',
        'js',
        'png',
        'jpg',
        'jpeg',
        'gif',
        'webp',
        'svg',
        'avif',
        'bmp',
        'ico',
        'mp4',
        'webm',
        'mov',
        'm4v',
        'ogv',
      }.contains(p.posix.extension(path).replaceFirst('.', '').toLowerCase());

  static DecodedPackageArchive _decode(
    (Uint8List, PackageArchiveLimits) request,
  ) {
    final (bytes, limits) = request;
    final directory = ZipDirectory()..read(InputMemoryStream(bytes));
    if (directory.fileHeaders.length > limits.entries) {
      throw const FormatException('压缩包文件数量超过限制');
    }
    final names = <String>{};
    var declaredTotal = 0;
    final pending = <(String, ZipFileHeader)>[];
    // Inspect all headers before inflating even the first file.
    for (final header in directory.fileHeaders) {
      final file = header.file!;
      final path = safePath(decodeArchiveFileName(file.filename));
      if (((header.externalFileAttributes >> 16) & 0xf000) == 0xa000) {
        throw const FormatException('压缩包不允许符号链接');
      }
      if (file.filename.endsWith('/') || file.filename.endsWith('\\')) continue;
      if (!allowedPath(path)) throw FormatException('压缩包包含不支持的文件类型：$path');
      if (!names.add(path.toLowerCase())) {
        throw FormatException('压缩包包含重复路径：$path');
      }
      if ((file.flags & 1) != 0) throw const FormatException('暂不支持加密压缩包');
      declaredTotal += header.uncompressedSize;
      if (header.uncompressedSize > limits.fileBytes ||
          file.uncompressedSize > limits.fileBytes ||
          declaredTotal > limits.totalBytes) {
        throw const FormatException('压缩包解压后大小超过限制');
      }
      pending.add((path, header));
    }
    if (pending.length < 2) {
      throw const FormatException('ZIP 或 .moyue 中至少需要包含 2 个文件');
    }
    final files = <String, Uint8List>{};
    final hashes = <String, String>{};
    var total = 0;
    for (final (path, header) in pending) {
      final file = header.file!;
      final output = _LimitedOutput(
        limits.fileBytes < limits.totalBytes - total
            ? limits.fileBytes
            : limits.totalBytes - total,
      );
      if (file.compressionMethod == CompressionType.deflate) {
        inflatePackageEntry(file.getStream(decompress: false), output);
      } else if (file.compressionMethod == CompressionType.bzip2 ||
          file.compressionMethod == CompressionType.none) {
        file.decompress(output);
      } else {
        throw const FormatException('不支持此 ZIP 压缩算法');
      }
      final data = output.getBytes();
      if (data.length != header.uncompressedSize ||
          data.length != file.uncompressedSize ||
          getCrc32(data) != header.crc32 ||
          header.crc32 != file.crc32) {
        throw FormatException('压缩包文件校验失败：$path');
      }
      total += data.length;
      files[path] = data;
      hashes[path] = _hash(data);
    }
    return DecodedPackageArchive(files, hashes);
  }

  static Uint8List _encode(
    (Map<String, Uint8List>, PackageArchiveLimits) request,
  ) {
    final (files, limits) = request;
    if (files.length > limits.entries) {
      throw const FormatException('文档包文件数量超过限制，请分批分享');
    }
    var total = 0;
    final archive = Archive();
    for (final entry in files.entries) {
      total += entry.value.length;
      if (entry.value.length > limits.fileBytes || total > limits.totalBytes) {
        throw const FormatException('文档包超过安全大小限制，请分批分享');
      }
      archive.addFile(ArchiveFile.bytes(safePath(entry.key), entry.value));
    }
    return ZipEncoder().encodeBytes(
      archive,
      output: _LimitedOutput(
        limits.compressedBytes,
        message: '文档包压缩后超过大小限制，请分批分享',
      ),
    );
  }
}

/// Checks actual decompressor writes, not just attacker-controlled ZIP sizes.
class _LimitedOutput extends OutputMemoryStream {
  _LimitedOutput(this.limit, {this.message = '压缩包解压后大小超过限制'});
  final int limit;
  final String message;
  void _check(int count) {
    if (length + count > limit) throw FormatException(message);
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _check(stream.length);
    super.writeStream(stream);
  }
}
