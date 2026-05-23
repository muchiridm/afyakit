// lib/features/clinical/prescriptions/models/prescription_model.dart

enum PrescriptionStatus {
  uploaded,
  processing,
  ready,
  failed;

  static PrescriptionStatus fromJson(Object? value) {
    final s = (value ?? '').toString().trim().toLowerCase();

    switch (s) {
      case 'processing':
        return PrescriptionStatus.processing;
      case 'ready':
        return PrescriptionStatus.ready;
      case 'failed':
        return PrescriptionStatus.failed;
      case 'uploaded':
      default:
        return PrescriptionStatus.uploaded;
    }
  }

  String get wireName {
    switch (this) {
      case PrescriptionStatus.uploaded:
        return 'uploaded';
      case PrescriptionStatus.processing:
        return 'processing';
      case PrescriptionStatus.ready:
        return 'ready';
      case PrescriptionStatus.failed:
        return 'failed';
    }
  }

  String get label {
    switch (this) {
      case PrescriptionStatus.uploaded:
        return 'Uploaded';
      case PrescriptionStatus.processing:
        return 'Processing';
      case PrescriptionStatus.ready:
        return 'Ready';
      case PrescriptionStatus.failed:
        return 'Failed';
    }
  }
}

class Prescription {
  const Prescription({
    required this.prescriptionId,
    required this.patientId,
    required this.fileName,
    required this.storagePath,
    this.originalStoragePath,
    this.thumbnailStoragePath,
    this.downloadUrl,
    this.contentType,
    this.sizeBytes,
    this.width,
    this.height,
    this.note,
    this.prescribedOn,
    required this.status,
    required this.isActive,
    this.uploadedByUid,
    this.createdAt,
    this.updatedAt,
  });

  final String prescriptionId;
  final String patientId;

  final String fileName;

  /// Main display path. For MVP this may equal [originalStoragePath].
  final String storagePath;

  final String? originalStoragePath;
  final String? thumbnailStoragePath;

  final String? downloadUrl;

  final String? contentType;
  final int? sizeBytes;

  final int? width;
  final int? height;

  final String? note;
  final String? prescribedOn;

  final PrescriptionStatus status;
  final bool isActive;

  final String? uploadedByUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static String _readString(
    Map<String, Object?> json,
    String key, {
    String fallback = '',
  }) {
    final v = json[key];
    if (v == null) return fallback;
    return v.toString();
  }

  static String? _readNullableString(Map<String, Object?> json, String key) {
    final v = json[key];
    if (v == null) return null;

    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _readNullableInt(Map<String, Object?> json, String key) {
    final v = json[key];
    if (v == null) return null;

    if (v is int) return v;
    if (v is num) return v.toInt();

    final parsed = int.tryParse(v.toString());
    return parsed;
  }

  static bool _readBool(
    Map<String, Object?> json,
    String key, {
    bool fallback = false,
  }) {
    final v = json[key];

    if (v is bool) return v;

    final s = (v ?? '').toString().trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;

    return fallback;
  }

  static DateTime? _readDateTime(Map<String, Object?> json, String key) {
    final s = _readNullableString(json, key);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  factory Prescription.fromJson(Map<String, Object?> json) {
    return Prescription(
      prescriptionId: _readString(json, 'prescription_id'),
      patientId: _readString(json, 'patient_id'),
      fileName: _readString(json, 'file_name'),
      storagePath: _readString(json, 'storage_path'),
      originalStoragePath: _readNullableString(json, 'original_storage_path'),
      thumbnailStoragePath: _readNullableString(json, 'thumbnail_storage_path'),
      downloadUrl: _readNullableString(json, 'download_url'),
      contentType: _readNullableString(json, 'content_type'),
      sizeBytes: _readNullableInt(json, 'size_bytes'),
      width: _readNullableInt(json, 'width'),
      height: _readNullableInt(json, 'height'),
      note: _readNullableString(json, 'note'),
      prescribedOn: _readNullableString(json, 'prescribed_on'),
      status: PrescriptionStatus.fromJson(json['status']),
      isActive: _readBool(json, 'is_active', fallback: true),
      uploadedByUid: _readNullableString(json, 'uploaded_by_uid'),
      createdAt: _readDateTime(json, 'created_at'),
      updatedAt: _readDateTime(json, 'updated_at'),
    );
  }
}

class PrescriptionCreateInput {
  const PrescriptionCreateInput({
    required this.patientId,
    required this.fileName,
    required this.storagePath,
    this.originalStoragePath,
    this.thumbnailStoragePath,
    this.downloadUrl,
    this.contentType,
    this.sizeBytes,
    this.width,
    this.height,
    this.note,
    this.prescribedOn,
    this.status = PrescriptionStatus.uploaded,
    this.isActive = true,
  });

  final String patientId;
  final String fileName;
  final String storagePath;

  final String? originalStoragePath;
  final String? thumbnailStoragePath;

  final String? downloadUrl;

  final String? contentType;
  final int? sizeBytes;

  final int? width;
  final int? height;

  final String? note;
  final String? prescribedOn;

  final PrescriptionStatus status;
  final bool isActive;

  Map<String, Object?> toJson() {
    return {
      'patient_id': patientId,
      'file_name': fileName,
      'storage_path': storagePath,
      if (originalStoragePath != null)
        'original_storage_path': originalStoragePath,
      if (thumbnailStoragePath != null)
        'thumbnail_storage_path': thumbnailStoragePath,
      if (downloadUrl != null) 'download_url': downloadUrl,
      if (contentType != null) 'content_type': contentType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (note != null) 'note': note,
      if (prescribedOn != null) 'prescribed_on': prescribedOn,
      'status': status.wireName,
      'is_active': isActive,
    };
  }
}

class PrescriptionUpdateInput {
  const PrescriptionUpdateInput({
    this.fileName,
    this.storagePath,
    this.originalStoragePath,
    this.thumbnailStoragePath,
    this.downloadUrl,
    this.contentType,
    this.sizeBytes,
    this.width,
    this.height,
    this.note,
    this.prescribedOn,
    this.status,
    this.isActive,
  });

  final String? fileName;
  final String? storagePath;

  final String? originalStoragePath;
  final String? thumbnailStoragePath;

  final String? downloadUrl;

  final String? contentType;
  final int? sizeBytes;

  final int? width;
  final int? height;

  final String? note;
  final String? prescribedOn;

  final PrescriptionStatus? status;
  final bool? isActive;

  Map<String, Object?> toJson() {
    return {
      if (fileName != null) 'file_name': fileName,
      if (storagePath != null) 'storage_path': storagePath,
      if (originalStoragePath != null)
        'original_storage_path': originalStoragePath,
      if (thumbnailStoragePath != null)
        'thumbnail_storage_path': thumbnailStoragePath,
      if (downloadUrl != null) 'download_url': downloadUrl,
      if (contentType != null) 'content_type': contentType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (note != null) 'note': note,
      if (prescribedOn != null) 'prescribed_on': prescribedOn,
      if (status != null) 'status': status!.wireName,
      if (isActive != null) 'is_active': isActive,
    };
  }
}
