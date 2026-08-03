// lib/features/insurance/documents/services/insurance_document_storage_paths.dart

import 'dart:math';

final class InsuranceDocumentStoragePaths {
  const InsuranceDocumentStoragePaths._();

  static String newUploadId() {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final String rand = Random.secure().nextInt(0x7fffffff).toRadixString(36);

    return 'insurance_document_${now.toRadixString(36)}_$rand';
  }

  static String cleanExt(String? ext) {
    final String raw = (ext ?? '').trim().toLowerCase().replaceAll('.', '');

    if (raw == 'jpeg') return 'jpg';

    switch (raw) {
      case 'jpg':
      case 'png':
      case 'webp':
      case 'pdf':
        return raw;
      default:
        return 'pdf';
    }
  }

  static String contentTypeForExt(String ext) {
    switch (cleanExt(ext)) {
      case 'jpg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
      default:
        return 'application/pdf';
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
      'insurance_documents',
      _safeSegment(uploadId),
      'original.${cleanExt(ext)}',
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
      'insurance_documents',
      _safeSegment(uploadId),
      'thumb.jpg',
    ].join('/');
  }

  static String _safeSegment(String value) {
    return value.trim().replaceAll(RegExp(r'[/\\]+'), '_');
  }
}
