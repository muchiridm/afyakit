// lib/features/insurance/claims/models/insurance_claim.dart

enum InsuranceClaimStatus {
  uploaded,
  pendingReview,
  verified,
  rejected,
  submitted,
  approved,
  paid,
  cancelled,
}

extension InsuranceClaimStatusX on InsuranceClaimStatus {
  String get wire {
    switch (this) {
      case InsuranceClaimStatus.uploaded:
        return 'uploaded';
      case InsuranceClaimStatus.pendingReview:
        return 'pending_review';
      case InsuranceClaimStatus.verified:
        return 'verified';
      case InsuranceClaimStatus.rejected:
        return 'rejected';
      case InsuranceClaimStatus.submitted:
        return 'submitted';
      case InsuranceClaimStatus.approved:
        return 'approved';
      case InsuranceClaimStatus.paid:
        return 'paid';
      case InsuranceClaimStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case InsuranceClaimStatus.uploaded:
        return 'Uploaded';
      case InsuranceClaimStatus.pendingReview:
        return 'Pending Review';
      case InsuranceClaimStatus.verified:
        return 'Verified';
      case InsuranceClaimStatus.rejected:
        return 'Rejected';
      case InsuranceClaimStatus.submitted:
        return 'Submitted';
      case InsuranceClaimStatus.approved:
        return 'Approved';
      case InsuranceClaimStatus.paid:
        return 'Paid';
      case InsuranceClaimStatus.cancelled:
        return 'Cancelled';
    }
  }

  static InsuranceClaimStatus fromWire(Object? value) {
    final String s = _cleanString(value);

    for (final InsuranceClaimStatus status in InsuranceClaimStatus.values) {
      if (status.wire == s) return status;
    }

    return InsuranceClaimStatus.uploaded;
  }
}

class InsuranceClaim {
  const InsuranceClaim({
    required this.claimId,
    required this.patientId,
    required this.membershipId,
    required this.fileName,
    required this.storagePath,
    this.originalStoragePath,
    this.thumbnailStoragePath,
    this.downloadUrl,
    this.contentType,
    this.sizeBytes,
    this.width,
    this.height,
    this.patientNo,
    this.patientDisplayName,
    this.payerContactId,
    this.payerDisplayName,
    this.memberNo,
    this.medicalCardNo,
    this.policyNo,
    this.memberName,
    this.principalName,
    this.scheme,
    this.invoiceId,
    this.invoiceNumber,
    this.prescriptionId,
    this.prescriptionNo,
    this.prescriberName,
    this.authCode,
    this.claimNo,
    this.visitNo,
    this.serviceDate,
    this.diagnosis,
    this.icd10Code,
    this.notes,
    this.submittedAt,
    this.submittedByUid,
    required this.status,
    required this.isActive,
    this.uploadedByUid,
    this.createdAt,
    this.updatedAt,
  });

  final String claimId;

  final String patientId;
  final String membershipId;

  /// Uploaded insurance claim document metadata.
  final String fileName;
  final String storagePath;
  final String? originalStoragePath;
  final String? thumbnailStoragePath;
  final String? downloadUrl;

  final String? contentType;
  final int? sizeBytes;

  final int? width;
  final int? height;

  /// Cached patient display fields.
  final String? patientNo;
  final String? patientDisplayName;

  /// Cached insurance/membership display fields.
  final String? payerContactId;
  final String? payerDisplayName;

  final String? memberNo;
  final String? medicalCardNo;
  final String? policyNo;

  final String? memberName;
  final String? principalName;
  final String? scheme;

  /// Optional invoice linkage.
  final String? invoiceId;
  final String? invoiceNumber;

  /// Optional prescription linkage.
  final String? prescriptionId;
  final String? prescriptionNo;
  final String? prescriberName;

  /// Optional insurer/admin metadata.
  final String? authCode;
  final String? claimNo;
  final String? visitNo;
  final String? serviceDate;

  final String? diagnosis;
  final String? icd10Code;
  final String? notes;

  final String? submittedAt;
  final String? submittedByUid;

  final InsuranceClaimStatus status;
  final bool isActive;

  final String? uploadedByUid;
  final String? createdAt;
  final String? updatedAt;

  bool get hasFile => _hasText(storagePath) || _hasText(downloadUrl);

  bool get hasInvoice => _hasText(invoiceId) || _hasText(invoiceNumber);

  bool get hasPrescription =>
      _hasText(prescriptionId) || _hasText(prescriptionNo);

  bool get hasMembership => _hasText(membershipId);

  factory InsuranceClaim.fromJson(Map<String, Object?> json) {
    return InsuranceClaim(
      claimId: _s(json['claim_id']),
      patientId: _s(json['patient_id']),
      membershipId: _s(json['membership_id']),
      fileName: _s(json['file_name']),
      storagePath: _s(json['storage_path']),
      originalStoragePath: _sn(json['original_storage_path']),
      thumbnailStoragePath: _sn(json['thumbnail_storage_path']),
      downloadUrl: _sn(json['download_url']),
      contentType: _sn(json['content_type']),
      sizeBytes: _intn(json['size_bytes']),
      width: _intn(json['width']),
      height: _intn(json['height']),
      patientNo: _sn(json['patient_no']),
      patientDisplayName: _sn(json['patient_display_name']),
      payerContactId: _sn(json['payer_contact_id']),
      payerDisplayName: _sn(json['payer_display_name']),
      memberNo: _sn(json['member_no']),
      medicalCardNo: _sn(json['medical_card_no']),
      policyNo: _sn(json['policy_no']),
      memberName: _sn(json['member_name']),
      principalName: _sn(json['principal_name']),
      scheme: _sn(json['scheme']),
      invoiceId: _sn(json['invoice_id']),
      invoiceNumber: _sn(json['invoice_number']),
      prescriptionId: _sn(json['prescription_id']),
      prescriptionNo: _sn(json['prescription_no']),
      prescriberName: _sn(json['prescriber_name']),
      authCode: _sn(json['auth_code']),
      claimNo: _sn(json['claim_no']),
      visitNo: _sn(json['visit_no']),
      serviceDate: _sn(json['service_date']),
      diagnosis: _sn(json['diagnosis']),
      icd10Code: _sn(json['icd10_code']),
      notes: _sn(json['notes']),
      submittedAt: _sn(json['submitted_at']),
      submittedByUid: _sn(json['submitted_by_uid']),
      status: InsuranceClaimStatusX.fromWire(json['status']),
      isActive: json['is_active'] == true,
      uploadedByUid: _sn(json['uploaded_by_uid']),
      createdAt: _sn(json['created_at']),
      updatedAt: _sn(json['updated_at']),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'claim_id': claimId,
      'patient_id': patientId,
      'membership_id': membershipId,
      'file_name': fileName,
      'storage_path': storagePath,
      'original_storage_path': originalStoragePath,
      'thumbnail_storage_path': thumbnailStoragePath,
      'download_url': downloadUrl,
      'content_type': contentType,
      'size_bytes': sizeBytes,
      'width': width,
      'height': height,
      'patient_no': patientNo,
      'patient_display_name': patientDisplayName,
      'payer_contact_id': payerContactId,
      'payer_display_name': payerDisplayName,
      'member_no': memberNo,
      'medical_card_no': medicalCardNo,
      'policy_no': policyNo,
      'member_name': memberName,
      'principal_name': principalName,
      'scheme': scheme,
      'invoice_id': invoiceId,
      'invoice_number': invoiceNumber,
      'prescription_id': prescriptionId,
      'prescription_no': prescriptionNo,
      'prescriber_name': prescriberName,
      'auth_code': authCode,
      'claim_no': claimNo,
      'visit_no': visitNo,
      'service_date': serviceDate,
      'diagnosis': diagnosis,
      'icd10_code': icd10Code,
      'notes': notes,
      'submitted_at': submittedAt,
      'submitted_by_uid': submittedByUid,
      'status': status.wire,
      'is_active': isActive,
      'uploaded_by_uid': uploadedByUid,
      'created_at': createdAt,
      'updated_at': updatedAt,
    }..removeWhere(_removeEmpty);
  }
}

class InsuranceClaimCreateInput {
  const InsuranceClaimCreateInput({
    required this.membershipId,
    required this.fileName,
    required this.storagePath,
    this.originalStoragePath,
    this.thumbnailStoragePath,
    this.downloadUrl,
    this.contentType,
    this.sizeBytes,
    this.width,
    this.height,
    this.invoiceId,
    this.invoiceNumber,
    this.prescriptionId,
    this.prescriptionNo,
    this.prescriberName,
    this.authCode,
    this.claimNo,
    this.visitNo,
    this.serviceDate,
    this.diagnosis,
    this.icd10Code,
    this.notes,
    this.submittedAt,
    this.submittedByUid,
    this.status,
    this.isActive,
  });

  final String membershipId;

  final String fileName;
  final String storagePath;
  final String? originalStoragePath;
  final String? thumbnailStoragePath;
  final String? downloadUrl;

  final String? contentType;
  final int? sizeBytes;

  final int? width;
  final int? height;

  final String? invoiceId;
  final String? invoiceNumber;

  final String? prescriptionId;
  final String? prescriptionNo;
  final String? prescriberName;

  final String? authCode;
  final String? claimNo;
  final String? visitNo;
  final String? serviceDate;

  final String? diagnosis;
  final String? icd10Code;
  final String? notes;

  final String? submittedAt;
  final String? submittedByUid;

  final InsuranceClaimStatus? status;
  final bool? isActive;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'membership_id': membershipId,
      'file_name': fileName,
      'storage_path': storagePath,
      'original_storage_path': originalStoragePath,
      'thumbnail_storage_path': thumbnailStoragePath,
      'download_url': downloadUrl,
      'content_type': contentType,
      'size_bytes': sizeBytes,
      'width': width,
      'height': height,
      'invoice_id': invoiceId,
      'invoice_number': invoiceNumber,
      'prescription_id': prescriptionId,
      'prescription_no': prescriptionNo,
      'prescriber_name': prescriberName,
      'auth_code': authCode,
      'claim_no': claimNo,
      'visit_no': visitNo,
      'service_date': serviceDate,
      'diagnosis': diagnosis,
      'icd10_code': icd10Code,
      'notes': notes,
      'submitted_at': submittedAt,
      'submitted_by_uid': submittedByUid,
      'status': status?.wire,
      'is_active': isActive,
    }..removeWhere(_removeEmpty);
  }
}

class InsuranceClaimUpdateInput {
  const InsuranceClaimUpdateInput({
    this.membershipId,
    this.fileName,
    this.storagePath,
    this.originalStoragePath,
    this.thumbnailStoragePath,
    this.downloadUrl,
    this.contentType,
    this.sizeBytes,
    this.width,
    this.height,
    this.invoiceId,
    this.invoiceNumber,
    this.prescriptionId,
    this.prescriptionNo,
    this.prescriberName,
    this.authCode,
    this.claimNo,
    this.visitNo,
    this.serviceDate,
    this.diagnosis,
    this.icd10Code,
    this.notes,
    this.submittedAt,
    this.submittedByUid,
    this.status,
    this.isActive,
  });

  final String? membershipId;

  final String? fileName;
  final String? storagePath;
  final String? originalStoragePath;
  final String? thumbnailStoragePath;
  final String? downloadUrl;

  final String? contentType;
  final int? sizeBytes;

  final int? width;
  final int? height;

  final String? invoiceId;
  final String? invoiceNumber;

  final String? prescriptionId;
  final String? prescriptionNo;
  final String? prescriberName;

  final String? authCode;
  final String? claimNo;
  final String? visitNo;
  final String? serviceDate;

  final String? diagnosis;
  final String? icd10Code;
  final String? notes;

  final String? submittedAt;
  final String? submittedByUid;

  final InsuranceClaimStatus? status;
  final bool? isActive;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'membership_id': membershipId,
      'file_name': fileName,
      'storage_path': storagePath,
      'original_storage_path': originalStoragePath,
      'thumbnail_storage_path': thumbnailStoragePath,
      'download_url': downloadUrl,
      'content_type': contentType,
      'size_bytes': sizeBytes,
      'width': width,
      'height': height,
      'invoice_id': invoiceId,
      'invoice_number': invoiceNumber,
      'prescription_id': prescriptionId,
      'prescription_no': prescriptionNo,
      'prescriber_name': prescriberName,
      'auth_code': authCode,
      'claim_no': claimNo,
      'visit_no': visitNo,
      'service_date': serviceDate,
      'diagnosis': diagnosis,
      'icd10_code': icd10Code,
      'notes': notes,
      'submitted_at': submittedAt,
      'submitted_by_uid': submittedByUid,
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
