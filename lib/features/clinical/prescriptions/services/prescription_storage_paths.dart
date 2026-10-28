import 'dart:math';

final class PrescriptionStoragePaths {
  const PrescriptionStoragePaths._();

  static const int maxFileBytes = 20 * 1024 * 1024;

  static String newUploadId() {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final rand = Random.secure().nextInt(0x7fffffff).toRadixString(36);
    return 'rx_${now.toRadixString(36)}_$rand';
  }

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
      case 'jpg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      default: return 'application/pdf';
    }
  }

  static String _base(String tenantId, String appId, String profileId, String uploadId) => [
    'tenants', _safeSegment(tenantId), 'apps', _safeSegment(appId),
    'health_profiles', _safeSegment(profileId), 'prescriptions', _safeSegment(uploadId),
  ].join('/');

  static String originalPath({
    required String tenantId, required String appId,
    required String profileId,
    required String uploadId,
    required String ext,
  }) => '${_base(tenantId, appId, profileId, uploadId)}/original.${cleanExt(ext)}';

  static String thumbnailPath({
    required String tenantId, required String appId,
    required String profileId,
    required String uploadId,
  }) => '${_base(tenantId, appId, profileId, uploadId)}/thumb.jpg';

  static String standardPath({
    required String tenantId, required String appId,
    required String profileId,
    required String uploadId,
  }) => '${_base(tenantId, appId, profileId, uploadId)}/standard.jpg';

  static String _safeSegment(String value) {
    if (value.isEmpty || value != value.trim() || value == '.' || value == '..' ||
        value.contains('/') || value.contains('\\') ||
        value.codeUnits.any((code) => code < 32 || code == 127)) {
      throw ArgumentError.value(value, 'path segment', 'Invalid path segment');
    }
    return value;
  }
}
