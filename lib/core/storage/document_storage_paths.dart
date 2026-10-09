// lib/core/storage/document_storage_paths.dart

import 'dart:math';

/// Shared storage conventions for profile-associated documents.
///
/// Storage layout:
/// tenants/{tenantId}/apps/{appId}/health_profiles/
/// {profileId}/{kind}/{uploadId}/original.{ext}
final class DocumentStoragePaths {
  const DocumentStoragePaths._();

  static const int maxFileBytes = 20 * 1024 * 1024;

  static const Map<String, String> contentTypes = {
    'jpg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'pdf': 'application/pdf',
  };

  static String newUploadId() {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final random = Random.secure().nextInt(0x7fffffff);

    return '${now.toRadixString(36)}_${random.toRadixString(36)}';
  }

  static String cleanExt(String? extension) {
    var ext = (extension ?? '').trim().toLowerCase();

    if (ext.startsWith('.')) {
      ext = ext.substring(1);
    }

    if (ext == 'jpeg') ext = 'jpg';

    if (!contentTypes.containsKey(ext)) {
      throw ArgumentError.value(
        extension,
        'extension',
        'Use JPG, PNG, WebP or PDF',
      );
    }

    return ext;
  }

  static String contentTypeForExt(String extension) {
    return contentTypes[cleanExt(extension)]!;
  }

  static String safeSegment(String value) {
    if (value.isEmpty ||
        value != value.trim() ||
        value == '.' ||
        value == '..' ||
        value.contains('/') ||
        value.contains('\\') ||
        value.codeUnits.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(
        value,
        'path segment',
        'Invalid storage path segment',
      );
    }

    return value;
  }

  static String prefix({
    required String tenantId,
    required String appId,
    required String profileId,
    required String kind,
  }) {
    return [
      'tenants',
      safeSegment(tenantId),
      'apps',
      safeSegment(appId),
      'health_profiles',
      safeSegment(profileId),
      safeSegment(kind),
    ].join('/');
  }

  static String uploadPrefix({
    required String tenantId,
    required String appId,
    required String profileId,
    required String kind,
    required String uploadId,
  }) {
    return [
      prefix(
        tenantId: tenantId,
        appId: appId,
        profileId: profileId,
        kind: kind,
      ),
      safeSegment(uploadId),
    ].join('/');
  }

  static String originalPath({
    required String tenantId,
    required String appId,
    required String profileId,
    required String kind,
    required String uploadId,
    required String ext,
  }) {
    final base = uploadPrefix(
      tenantId: tenantId,
      appId: appId,
      profileId: profileId,
      kind: kind,
      uploadId: uploadId,
    );

    return '$base/original.${cleanExt(ext)}';
  }

  static String thumbnailPath({
    required String tenantId,
    required String appId,
    required String profileId,
    required String kind,
    required String uploadId,
  }) {
    final base = uploadPrefix(
      tenantId: tenantId,
      appId: appId,
      profileId: profileId,
      kind: kind,
      uploadId: uploadId,
    );

    return '$base/thumb.jpg';
  }

  static bool belongsToScope({
    required String storagePath,
    required String tenantId,
    required String appId,
    required String profileId,
    required String kind,
  }) {
    final base = prefix(
      tenantId: tenantId,
      appId: appId,
      profileId: profileId,
      kind: kind,
    );

    final path = storagePath.trim();

    if (path != storagePath || !path.startsWith('$base/')) {
      return false;
    }

    final remainder = path.substring(base.length + 1);
    final segments = remainder.split('/');

    if (segments.any((segment) => segment.isEmpty)) {
      return false;
    }

    try {
      for (final segment in segments) {
        safeSegment(segment);
      }
    } on ArgumentError {
      return false;
    }

    return true;
  }
}
