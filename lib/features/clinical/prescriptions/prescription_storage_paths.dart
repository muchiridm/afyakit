// lib/features/clinical/prescriptions/prescription_storage_paths.dart

final class PrescriptionStoragePaths {
  const PrescriptionStoragePaths._();

  static const int maxFileBytes = 20 * 1024 * 1024;

  static String cleanExt(String? ext) {
    var raw = (ext ?? '').trim().toLowerCase();
    if (raw.startsWith('.')) raw = raw.substring(1);
    if (raw == 'jpeg') raw = 'jpg';
    if (!const ['jpg', 'png', 'webp', 'pdf'].contains(raw)) {
      throw ArgumentError.value(ext, 'extension', 'Use JPG, PNG, WebP or PDF');
    }
    return raw;
  }

  static String contentTypeForExt(String ext) {
    switch (cleanExt(ext)) {
      case 'jpg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/pdf';
    }
  }

  /// Append the file name to the server-allocated prefix; never allocate IDs.
  static String originalPath({
    required String storagePrefix,
    required String ext,
  }) {
    final prefix = storagePrefix.endsWith('/')
        ? storagePrefix.substring(0, storagePrefix.length - 1)
        : storagePrefix;
    for (final segment in prefix.split('/')) {
      _safeSegment(segment);
    }
    return '$prefix/original.${cleanExt(ext)}';
  }

  static String _safeSegment(String value) {
    if (value.isEmpty ||
        value != value.trim() ||
        value == '.' ||
        value == '..' ||
        value.contains('/') ||
        value.contains('\\') ||
        value.codeUnits.any((code) => code < 32 || code == 127)) {
      throw ArgumentError.value(value, 'path segment', 'Invalid path segment');
    }
    return value;
  }
}
