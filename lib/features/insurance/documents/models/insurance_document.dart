// lib/features/insurance/documents/models/insurance_document.dart

enum InsuranceDocumentType {
  claimForm,
  membershipCard,
  authorization,
  labResult,
  dischargeSummary,
  other,
}

extension InsuranceDocumentTypeX on InsuranceDocumentType {
  String get wire {
    switch (this) {
      case InsuranceDocumentType.claimForm:
        return 'claim_form';
      case InsuranceDocumentType.membershipCard:
        return 'membership_card';
      case InsuranceDocumentType.authorization:
        return 'authorization';
      case InsuranceDocumentType.labResult:
        return 'lab_result';
      case InsuranceDocumentType.dischargeSummary:
        return 'discharge_summary';
      case InsuranceDocumentType.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case InsuranceDocumentType.claimForm:
        return 'Claim Form';
      case InsuranceDocumentType.membershipCard:
        return 'Membership Card';
      case InsuranceDocumentType.authorization:
        return 'Authorization';
      case InsuranceDocumentType.labResult:
        return 'Lab Result';
      case InsuranceDocumentType.dischargeSummary:
        return 'Discharge Summary';
      case InsuranceDocumentType.other:
        return 'Other';
    }
  }

  static InsuranceDocumentType fromWire(Object? value) {
    final String s = _cleanString(value);

    for (final InsuranceDocumentType type in InsuranceDocumentType.values) {
      if (type.wire == s) return type;
    }

    return InsuranceDocumentType.other;
  }
}

enum InsuranceDocumentStatus { uploaded, verified, rejected, archived }

extension InsuranceDocumentStatusX on InsuranceDocumentStatus {
  String get wire {
    switch (this) {
      case InsuranceDocumentStatus.uploaded:
        return 'uploaded';
      case InsuranceDocumentStatus.verified:
        return 'verified';
      case InsuranceDocumentStatus.rejected:
        return 'rejected';
      case InsuranceDocumentStatus.archived:
        return 'archived';
    }
  }

  String get label {
    switch (this) {
      case InsuranceDocumentStatus.uploaded:
        return 'Uploaded';
      case InsuranceDocumentStatus.verified:
        return 'Verified';
      case InsuranceDocumentStatus.rejected:
        return 'Rejected';
      case InsuranceDocumentStatus.archived:
        return 'Archived';
    }
  }

  static InsuranceDocumentStatus fromWire(Object? value) {
    final String s = _cleanString(value);

    for (final InsuranceDocumentStatus status
        in InsuranceDocumentStatus.values) {
      if (status.wire == s) return status;
    }

    return InsuranceDocumentStatus.uploaded;
  }
}

class InsuranceDocument {
  const InsuranceDocument({
    required this.documentId,
    required this.patientId,
    this.claimPackId,
    required this.documentType,
    required this.fileName,
    required this.storagePath,
    this.originalStoragePath,
    this.thumbnailStoragePath,
    this.downloadUrl,
    this.contentType,
    this.sizeBytes,
    this.width,
    this.height,
    this.membershipId,
    this.payerContactId,
    this.payerDisplayName,
    this.title,
    this.notes,
    required this.status,
    required this.isActive,
    this.uploadedByUid,
    this.createdAt,
    this.updatedAt,
  });

  final String documentId;

  final String patientId;
  final String? claimPackId;

  final InsuranceDocumentType documentType;

  final String fileName;
  final String storagePath;

  final String? originalStoragePath;
  final String? thumbnailStoragePath;

  final String? downloadUrl;

  final String? contentType;
  final int? sizeBytes;

  final int? width;
  final int? height;

  final String? membershipId;

  final String? payerContactId;
  final String? payerDisplayName;

  final String? title;
  final String? notes;

  final InsuranceDocumentStatus status;
  final bool isActive;

  final String? uploadedByUid;

  final String? createdAt;
  final String? updatedAt;

  bool get hasFile => _hasText(storagePath) || _hasText(downloadUrl);

  bool get linkedToClaimPack => _hasText(claimPackId);

  factory InsuranceDocument.fromJson(Map<String, Object?> json) {
    return InsuranceDocument(
      documentId: _s(json['document_id']),
      patientId: _s(json['patient_id']),
      claimPackId: _sn(json['claim_pack_id']),
      documentType: InsuranceDocumentTypeX.fromWire(json['document_type']),
      fileName: _s(json['file_name']),
      storagePath: _s(json['storage_path']),
      originalStoragePath: _sn(json['original_storage_path']),
      thumbnailStoragePath: _sn(json['thumbnail_storage_path']),
      downloadUrl: _sn(json['download_url']),
      contentType: _sn(json['content_type']),
      sizeBytes: _intn(json['size_bytes']),
      width: _intn(json['width']),
      height: _intn(json['height']),
      membershipId: _sn(json['membership_id']),
      payerContactId: _sn(json['payer_contact_id']),
      payerDisplayName: _sn(json['payer_display_name']),
      title: _sn(json['title']),
      notes: _sn(json['notes']),
      status: InsuranceDocumentStatusX.fromWire(json['status']),
      isActive: json['is_active'] != false,
      uploadedByUid: _sn(json['uploaded_by_uid']),
      createdAt: _sn(json['created_at']),
      updatedAt: _sn(json['updated_at']),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'document_id': documentId,
      'patient_id': patientId,
      'claim_pack_id': claimPackId,
      'document_type': documentType.wire,
      'file_name': fileName,
      'storage_path': storagePath,
      'original_storage_path': originalStoragePath,
      'thumbnail_storage_path': thumbnailStoragePath,
      'download_url': downloadUrl,
      'content_type': contentType,
      'size_bytes': sizeBytes,
      'width': width,
      'height': height,
      'membership_id': membershipId,
      'payer_contact_id': payerContactId,
      'payer_display_name': payerDisplayName,
      'title': title,
      'notes': notes,
      'status': status.wire,
      'is_active': isActive,
      'uploaded_by_uid': uploadedByUid,
      'created_at': createdAt,
      'updated_at': updatedAt,
    }..removeWhere(_removeEmpty);
  }
}

class InsuranceDocumentCreateInput {
  const InsuranceDocumentCreateInput({
    this.claimPackId,
    required this.documentType,
    required this.fileName,
    required this.storagePath,
    this.originalStoragePath,
    this.thumbnailStoragePath,
    this.downloadUrl,
    this.contentType,
    this.sizeBytes,
    this.width,
    this.height,
    this.membershipId,
    this.payerContactId,
    this.payerDisplayName,
    this.title,
    this.notes,
    this.status,
    this.isActive,
  });

  final String? claimPackId;

  final InsuranceDocumentType documentType;

  final String fileName;
  final String storagePath;

  final String? originalStoragePath;
  final String? thumbnailStoragePath;

  final String? downloadUrl;

  final String? contentType;
  final int? sizeBytes;

  final int? width;
  final int? height;

  final String? membershipId;

  final String? payerContactId;
  final String? payerDisplayName;

  final String? title;
  final String? notes;

  final InsuranceDocumentStatus? status;
  final bool? isActive;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'claim_pack_id': claimPackId,
      'document_type': documentType.wire,
      'file_name': fileName,
      'storage_path': storagePath,
      'original_storage_path': originalStoragePath,
      'thumbnail_storage_path': thumbnailStoragePath,
      'download_url': downloadUrl,
      'content_type': contentType,
      'size_bytes': sizeBytes,
      'width': width,
      'height': height,
      'membership_id': membershipId,
      'payer_contact_id': payerContactId,
      'payer_display_name': payerDisplayName,
      'title': title,
      'notes': notes,
      'status': status?.wire,
      'is_active': isActive,
    }..removeWhere(_removeEmpty);
  }
}

class InsuranceDocumentUpdateInput {
  const InsuranceDocumentUpdateInput({
    this.claimPackId,
    this.documentType,
    this.fileName,
    this.storagePath,
    this.originalStoragePath,
    this.thumbnailStoragePath,
    this.downloadUrl,
    this.contentType,
    this.sizeBytes,
    this.width,
    this.height,
    this.membershipId,
    this.payerContactId,
    this.payerDisplayName,
    this.title,
    this.notes,
    this.status,
    this.isActive,
  });

  final String? claimPackId;

  final InsuranceDocumentType? documentType;

  final String? fileName;
  final String? storagePath;

  final String? originalStoragePath;
  final String? thumbnailStoragePath;

  final String? downloadUrl;

  final String? contentType;
  final int? sizeBytes;

  final int? width;
  final int? height;

  final String? membershipId;

  final String? payerContactId;
  final String? payerDisplayName;

  final String? title;
  final String? notes;

  final InsuranceDocumentStatus? status;
  final bool? isActive;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'claim_pack_id': claimPackId,
      'document_type': documentType?.wire,
      'file_name': fileName,
      'storage_path': storagePath,
      'original_storage_path': originalStoragePath,
      'thumbnail_storage_path': thumbnailStoragePath,
      'download_url': downloadUrl,
      'content_type': contentType,
      'size_bytes': sizeBytes,
      'width': width,
      'height': height,
      'membership_id': membershipId,
      'payer_contact_id': payerContactId,
      'payer_display_name': payerDisplayName,
      'title': title,
      'notes': notes,
      'status': status?.wire,
      'is_active': isActive,
    }..removeWhere(_removeEmpty);
  }
}

bool _hasText(String? value) => (value ?? '').trim().isNotEmpty;

bool _removeEmpty(Object? _, Object? value) {
  if (value == null) return true;
  if (value is String && value.trim().isEmpty) return true;
  return false;
}

String _cleanString(Object? value) => (value ?? '').toString().trim();

String _s(Object? value) => _cleanString(value);

String? _sn(Object? value) {
  final String s = _cleanString(value);
  return s.isEmpty ? null : s;
}

int? _intn(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();

  final String s = _cleanString(value);
  if (s.isEmpty) return null;

  return int.tryParse(s);
}
