abstract final class DocumentImportPolicy {
  static const supportedExtensions = <String>{
    'zip',
    'moyue',
    'md',
    'html',
    'htm',
  };

  static const textExtensions = <String>{'md', 'html', 'htm'};
  static const htmlExtensions = <String>{'html', 'htm'};

  static String extensionOf(String fileName) {
    final normalized = fileName.replaceAll('\\', '/');
    final basename = normalized.substring(normalized.lastIndexOf('/') + 1);
    final dot = basename.lastIndexOf('.');
    if (dot <= 0 || dot == basename.length - 1) return '';
    return basename.substring(dot + 1).toLowerCase();
  }

  static bool supportsFileName(String fileName) =>
      supportedExtensions.contains(extensionOf(fileName));

  static bool isTextFileName(String fileName) =>
      textExtensions.contains(extensionOf(fileName));

  static bool isHtmlFileName(String fileName) =>
      htmlExtensions.contains(extensionOf(fileName));
}
