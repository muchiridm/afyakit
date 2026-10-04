// lib/features/clinical/prescriptions/models/prescription_model.dart

enum PrescriptionStatus {
  uploaded,
  pendingReview,
  verified,
  rejected,
  used,
  expired;

  static PrescriptionStatus fromJson(Object? value) {
    final s = (value ?? '').toString().trim().toLowerCase();

    switch (s) {
      case 'pending_review':
        return PrescriptionStatus.pendingReview;
      case 'verified':
        return PrescriptionStatus.verified;
      case 'rejected':
        return PrescriptionStatus.rejected;
      case 'used':
        return PrescriptionStatus.used;
      case 'expired':
        return PrescriptionStatus.expired;
      case 'uploaded':
      default:
        return PrescriptionStatus.uploaded;
    }
  }

  String get wireName {
    switch (this) {
      case PrescriptionStatus.uploaded:
        return 'uploaded';
      case PrescriptionStatus.pendingReview:
        return 'pending_review';
      case PrescriptionStatus.verified:
        return 'verified';
      case PrescriptionStatus.rejected:
        return 'rejected';
      case PrescriptionStatus.used:
        return 'used';
      case PrescriptionStatus.expired:
        return 'expired';
    }
  }

  String get label {
    switch (this) {
      case PrescriptionStatus.uploaded:
        return 'Uploaded';
      case PrescriptionStatus.pendingReview:
        return 'Pending review';
      case PrescriptionStatus.verified:
        return 'Verified';
      case PrescriptionStatus.rejected:
        return 'Rejected';
      case PrescriptionStatus.used:
        return 'Used';
      case PrescriptionStatus.expired:
        return 'Expired';
    }
  }

  bool get canSupportClaim => this == PrescriptionStatus.verified;
}

class Prescription {
  const Prescription({
    required this.prescriptionId,
    required this.profileId,
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

  /// Health profile this prescription belongs to.
  final String profileId;

  final String fileName;

  /// Main display path.
  ///
  /// For MVP this may equal [originalStoragePath].
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
    final value = json[key];

    if (value == null) {
      return fallback;
    }

    return value.toString();
  }

  static String? _readNullableString(Map<String, Object?> json, String key) {
    final value = json[key];

    if (value == null) {
      return null;
    }

    final s = value.toString().trim();

    return s.isEmpty ? null : s;
  }

  static int? _readNullableInt(Map<String, Object?> json, String key) {
    final value = json[key];

    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  static bool _readBool(
    Map<String, Object?> json,
    String key, {
    bool fallback = false,
  }) {
    final value = json[key];

    if (value is bool) {
      return value;
    }

    final s = (value ?? '').toString().trim().toLowerCase();

    if (s == 'true' || s == '1' || s == 'yes') {
      return true;
    }

    if (s == 'false' || s == '0' || s == 'no') {
      return false;
    }

    return fallback;
  }

  static DateTime? _readDateTime(Map<String, Object?> json, String key) {
    final s = _readNullableString(json, key);

    if (s == null) {
      return null;
    }

    return DateTime.tryParse(s);
  }

  factory Prescription.fromJson(Map<String, Object?> json) {
    return Prescription(
      prescriptionId: _readString(json, 'prescription_id'),
      profileId: _readString(json, 'profile_id'),
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
    required this.profileId,
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

  final String profileId;

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
      'profile_id': profileId,
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
