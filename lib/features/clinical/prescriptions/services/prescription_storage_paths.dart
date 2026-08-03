// lib/features/clinical/prescriptions/services/prescription_storage_paths.dart

import 'dart:math';

final class PrescriptionStoragePaths {
  const PrescriptionStoragePaths._();

  static String newUploadId() {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final rand = Random.secure().nextInt(0x7fffffff).toRadixString(36);
    return 'rx_${now.toRadixString(36)}_$rand';
  }

  static String cleanExt(String? ext) {
    final raw = (ext ?? '').trim().toLowerCase().replaceAll('.', '');

    if (raw == 'jpeg') return 'jpg';

    switch (raw) {
      case 'jpg':
      case 'png':
      case 'webp':
      case 'pdf':
        return raw;
      default:
        return 'jpg';
    }
  }

  static String contentTypeForExt(String ext) {
    switch (cleanExt(ext)) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }

  static String originalPath({
    required String tenantId,
    required String patientId,
    required String uploadId,
    required String ext,
  }) {
    return [
      'tenants',
      _safeSegment(tenantId),
      'clinical_patients',
      _safeSegment(patientId),
      'prescriptions',
      _safeSegment(uploadId),
      'original.${cleanExt(ext)}',
    ].join('/');
  }

  static String standardPath({
    required String tenantId,
    required String patientId,
    required String uploadId,
  }) {
    return [
      'tenants',
      _safeSegment(tenantId),
      'clinical_patients',
      _safeSegment(patientId),
      'prescriptions',
      _safeSegment(uploadId),
      'standard.jpg',
    ].join('/');
  }

  static String thumbnailPath({
    required String tenantId,
    required String patientId,
    required String uploadId,
  }) {
    return [
      'tenants',
      _safeSegment(tenantId),
      'clinical_patients',
      _safeSegment(patientId),
      'prescriptions',
      _safeSegment(uploadId),
      'thumb.jpg',
    ].join('/');
  }

  static String _safeSegment(String value) {
    return value.trim().replaceAll(RegExp(r'[/\\]+'), '_');
  }
}
