// lib/features/insurance/claims/models/insurance_claim.dart

enum InsuranceClaimStatus {
  draft,
  ready,
  readyToSubmit,
  submitted,
  approved,
  rejected,
  paid,
  cancelled,
}

extension InsuranceClaimStatusX on InsuranceClaimStatus {
  String get wire {
    switch (this) {
      case InsuranceClaimStatus.draft:
        return 'draft';
      case InsuranceClaimStatus.ready:
        return 'ready';
      case InsuranceClaimStatus.readyToSubmit:
        return 'ready_to_submit';
      case InsuranceClaimStatus.submitted:
        return 'submitted';
      case InsuranceClaimStatus.approved:
        return 'approved';
      case InsuranceClaimStatus.rejected:
        return 'rejected';
      case InsuranceClaimStatus.paid:
        return 'paid';
      case InsuranceClaimStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case InsuranceClaimStatus.draft:
        return 'Draft';
      case InsuranceClaimStatus.ready:
        return 'Ready';
      case InsuranceClaimStatus.readyToSubmit:
        return 'Ready to Submit';
      case InsuranceClaimStatus.submitted:
        return 'Submitted';
      case InsuranceClaimStatus.approved:
        return 'Approved';
      case InsuranceClaimStatus.rejected:
        return 'Rejected';
      case InsuranceClaimStatus.paid:
        return 'Paid';
      case InsuranceClaimStatus.cancelled:
        return 'Cancelled';
    }
  }

  static InsuranceClaimStatus fromWire(Object? value) {
    final s = (value ?? '').toString().trim();

    for (final status in InsuranceClaimStatus.values) {
      if (status.wire == s) return status;
    }

    return InsuranceClaimStatus.draft;
  }
}

enum ClaimFormStatus { pending, completed, signed, attached }

extension ClaimFormStatusX on ClaimFormStatus {
  String get wire {
    switch (this) {
      case ClaimFormStatus.pending:
        return 'pending';
      case ClaimFormStatus.completed:
        return 'completed';
      case ClaimFormStatus.signed:
        return 'signed';
      case ClaimFormStatus.attached:
        return 'attached';
    }
  }

  String get label {
    switch (this) {
      case ClaimFormStatus.pending:
        return 'Pending';
      case ClaimFormStatus.completed:
        return 'Completed';
      case ClaimFormStatus.signed:
        return 'Signed';
      case ClaimFormStatus.attached:
        return 'Attached';
    }
  }

  static ClaimFormStatus fromWire(Object? value) {
    final s = (value ?? '').toString().trim();

    for (final status in ClaimFormStatus.values) {
      if (status.wire == s) return status;
    }

    return ClaimFormStatus.pending;
  }
}

enum EtimsStatus { pending, attached, notRequired, failed }

extension EtimsStatusX on EtimsStatus {
  String get wire {
    switch (this) {
      case EtimsStatus.pending:
        return 'pending';
      case EtimsStatus.attached:
        return 'attached';
      case EtimsStatus.notRequired:
        return 'not_required';
      case EtimsStatus.failed:
        return 'failed';
    }
  }

  String get label {
    switch (this) {
      case EtimsStatus.pending:
        return 'Pending';
      case EtimsStatus.attached:
        return 'Attached';
      case EtimsStatus.notRequired:
        return 'Not Required';
      case EtimsStatus.failed:
        return 'Failed';
    }
  }

  static EtimsStatus fromWire(Object? value) {
    final s = (value ?? '').toString().trim();

    for (final status in EtimsStatus.values) {
      if (status.wire == s) return status;
    }

    return EtimsStatus.pending;
  }
}

class InsuranceClaim {
  const InsuranceClaim({
    required this.claimId,
    required this.membershipId,
    required this.patientId,
    this.patientNo,
    this.patientDisplayName,
    required this.invoiceId,
    this.invoiceNumber,
    required this.payerContactId,
    this.payerDisplayName,
    required this.memberNo,
    this.memberName,
    this.principalName,
    this.scheme,
    this.medicalCardNo,
    this.policyNo,
    this.authCode,
    this.claimNo,
    this.visitNo,
    this.serviceDate,
    this.prescriptionNo,
    this.prescriberName,
    this.prescriptionId,
    this.prescriptionFileName,
    this.prescriptionUrl,
    this.prescriptionStoragePath,
    this.diagnosis,
    this.icd10Code,
    this.investigations,
    this.treatmentRecommendations,
    this.notes,
    this.claimFormStatus,
    this.claimFormUrl,
    this.claimFormFileName,
    this.claimFormStoragePath,
    this.claimFormOriginalStoragePath,
    this.claimFormThumbnailStoragePath,
    this.claimFormContentType,
    this.claimFormSizeBytes,
    this.invoicePdfUrl,
    this.etimsStatus,
    this.etimsNo,
    this.etimsUrl,
    this.submittedAt,
    this.submittedByUid,
    required this.status,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  final String claimId;
  final String membershipId;

  final String patientId;
  final String? patientNo;
  final String? patientDisplayName;

  final String invoiceId;
  final String? invoiceNumber;

  final String payerContactId;
  final String? payerDisplayName;

  final String memberNo;
  final String? memberName;
  final String? principalName;

  final String? scheme;
  final String? medicalCardNo;
  final String? policyNo;

  final String? authCode;
  final String? claimNo;
  final String? visitNo;
  final String? serviceDate;

  /// Admin / human Rx reference.
  final String? prescriptionNo;
  final String? prescriberName;

  /// Linked patient prescription record.
  ///
  /// Source of truth remains the patient prescription record. These fields are
  /// a lightweight claim-pack reference/snapshot for display and submission.
  final String? prescriptionId;
  final String? prescriptionFileName;
  final String? prescriptionUrl;
  final String? prescriptionStoragePath;

  final String? diagnosis;
  final String? icd10Code;
  final String? investigations;
  final String? treatmentRecommendations;
  final String? notes;

  /// Uploaded/scanned claim form metadata.
  final ClaimFormStatus? claimFormStatus;
  final String? claimFormUrl;
  final String? claimFormFileName;
  final String? claimFormStoragePath;
  final String? claimFormOriginalStoragePath;
  final String? claimFormThumbnailStoragePath;
  final String? claimFormContentType;
  final int? claimFormSizeBytes;

  final String? invoicePdfUrl;

  final EtimsStatus? etimsStatus;
  final String? etimsNo;
  final String? etimsUrl;

  final String? submittedAt;
  final String? submittedByUid;

  final InsuranceClaimStatus status;
  final bool isActive;

  final String? createdAt;
  final String? updatedAt;

  bool get hasClaimForm {
    return claimFormStatus == ClaimFormStatus.attached ||
        claimFormStatus == ClaimFormStatus.signed ||
        _hasText(claimFormUrl) ||
        _hasText(claimFormStoragePath) ||
        _hasText(claimFormOriginalStoragePath);
  }

  bool get hasPrescriptionEvidence {
    return _hasText(prescriptionId) ||
        _hasText(prescriptionNo) ||
        _hasText(prescriptionUrl) ||
        _hasText(prescriptionStoragePath);
  }

  bool get hasEtimsEvidence {
    return etimsStatus == EtimsStatus.attached ||
        etimsStatus == EtimsStatus.notRequired ||
        _hasText(etimsNo) ||
        _hasText(etimsUrl);
  }

  bool get isReadyForSubmission {
    return _hasText(invoiceId) &&
        hasClaimForm &&
        hasPrescriptionEvidence &&
        hasEtimsEvidence;
  }

  factory InsuranceClaim.fromJson(Map<String, Object?> json) {
    return InsuranceClaim(
      claimId: _s(json['claim_id']),
      membershipId: _s(json['membership_id']),
      patientId: _s(json['patient_id']),
      patientNo: _sn(json['patient_no']),
      patientDisplayName: _sn(json['patient_display_name']),
      invoiceId: _s(json['invoice_id']),
      invoiceNumber: _sn(json['invoice_number']),
      payerContactId: _s(json['payer_contact_id']),
      payerDisplayName: _sn(json['payer_display_name']),
      memberNo: _s(json['member_no'] ?? json['member_number']),
      memberName: _sn(json['member_name']),
      principalName: _sn(json['principal_name']),
      scheme: _sn(json['scheme']),
      medicalCardNo: _sn(
        json['medical_card_no'] ?? json['medical_card_number'],
      ),
      policyNo: _sn(json['policy_no'] ?? json['policy_number']),
      authCode: _sn(json['auth_code'] ?? json['authorization_number']),
      claimNo: _sn(json['claim_no'] ?? json['claim_number']),
      visitNo: _sn(json['visit_no'] ?? json['visit_number']),
      serviceDate: _sn(json['service_date']),
      prescriptionNo: _sn(
        json['prescription_no'] ?? json['prescription_number'],
      ),
      prescriberName: _sn(json['prescriber_name']),
      prescriptionId: _sn(json['prescription_id']),
      prescriptionFileName: _sn(json['prescription_file_name']),
      prescriptionUrl: _sn(json['prescription_url']),
      prescriptionStoragePath: _sn(json['prescription_storage_path']),
      diagnosis: _sn(json['diagnosis']),
      icd10Code: _sn(json['icd10_code']),
      investigations: _sn(json['investigations']),
      treatmentRecommendations: _sn(json['treatment_recommendations']),
      notes: _sn(json['notes']),
      claimFormStatus: json.containsKey('claim_form_status')
          ? ClaimFormStatusX.fromWire(json['claim_form_status'])
          : null,
      claimFormUrl: _sn(json['claim_form_url']),
      claimFormFileName: _sn(json['claim_form_file_name']),
      claimFormStoragePath: _sn(json['claim_form_storage_path']),
      claimFormOriginalStoragePath: _sn(
        json['claim_form_original_storage_path'],
      ),
      claimFormThumbnailStoragePath: _sn(
        json['claim_form_thumbnail_storage_path'],
      ),
      claimFormContentType: _sn(json['claim_form_content_type']),
      claimFormSizeBytes: _intn(json['claim_form_size_bytes']),
      invoicePdfUrl: _sn(json['invoice_pdf_url']),
      etimsStatus: json.containsKey('etims_status')
          ? EtimsStatusX.fromWire(json['etims_status'])
          : null,
      etimsNo: _sn(json['etims_no'] ?? json['etims_number']),
      etimsUrl: _sn(json['etims_url']),
      submittedAt: _sn(json['submitted_at']),
      submittedByUid: _sn(json['submitted_by_uid']),
      status: InsuranceClaimStatusX.fromWire(json['status']),
      isActive: json['is_active'] == true,
      createdAt: _sn(json['created_at']),
      updatedAt: _sn(json['updated_at']),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'claim_id': claimId,
      'membership_id': membershipId,
      'patient_id': patientId,
      'patient_no': patientNo,
      'patient_display_name': patientDisplayName,
      'invoice_id': invoiceId,
      'invoice_number': invoiceNumber,
      'payer_contact_id': payerContactId,
      'payer_display_name': payerDisplayName,
      'member_no': memberNo,
      'member_name': memberName,
      'principal_name': principalName,
      'scheme': scheme,
      'medical_card_no': medicalCardNo,
      'policy_no': policyNo,
      'auth_code': authCode,
      'claim_no': claimNo,
      'visit_no': visitNo,
      'service_date': serviceDate,
      'prescription_no': prescriptionNo,
      'prescriber_name': prescriberName,
      'prescription_id': prescriptionId,
      'prescription_file_name': prescriptionFileName,
      'prescription_url': prescriptionUrl,
      'prescription_storage_path': prescriptionStoragePath,
      'diagnosis': diagnosis,
      'icd10_code': icd10Code,
      'investigations': investigations,
      'treatment_recommendations': treatmentRecommendations,
      'notes': notes,
      'claim_form_status': claimFormStatus?.wire,
      'claim_form_url': claimFormUrl,
      'claim_form_file_name': claimFormFileName,
      'claim_form_storage_path': claimFormStoragePath,
      'claim_form_original_storage_path': claimFormOriginalStoragePath,
      'claim_form_thumbnail_storage_path': claimFormThumbnailStoragePath,
      'claim_form_content_type': claimFormContentType,
      'claim_form_size_bytes': claimFormSizeBytes,
      'invoice_pdf_url': invoicePdfUrl,
      'etims_status': etimsStatus?.wire,
      'etims_no': etimsNo,
      'etims_url': etimsUrl,
      'submitted_at': submittedAt,
      'submitted_by_uid': submittedByUid,
      'status': status.wire,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
    }..removeWhere(_removeEmpty);
  }

  static bool _hasText(String? value) => (value ?? '').trim().isNotEmpty;

  static bool _removeEmpty(Object? _, Object? value) {
    if (value == null) return true;
    if (value is String && value.trim().isEmpty) return true;
    return false;
  }

  static String _s(Object? value) => (value ?? '').toString().trim();

  static String? _sn(Object? value) {
    final s = (value ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _intn(Object? value) {
    if (value == null) return null;

    if (value is int) return value;

    if (value is num) return value.toInt();

    final s = value.toString().trim();
    if (s.isEmpty) return null;

    return int.tryParse(s);
  }
}

class InsuranceClaimUpsertInput {
  const InsuranceClaimUpsertInput({
    required this.membershipId,
    required this.invoiceId,
    this.invoiceNumber,
    this.authCode,
    this.claimNo,
    this.visitNo,
    this.serviceDate,
    this.prescriptionNo,
    this.prescriberName,
    this.prescriptionId,
    this.prescriptionFileName,
    this.prescriptionUrl,
    this.prescriptionStoragePath,
    this.diagnosis,
    this.icd10Code,
    this.investigations,
    this.treatmentRecommendations,
    this.notes,
    this.claimFormStatus,
    this.claimFormUrl,
    this.claimFormFileName,
    this.claimFormStoragePath,
    this.claimFormOriginalStoragePath,
    this.claimFormThumbnailStoragePath,
    this.claimFormContentType,
    this.claimFormSizeBytes,
    this.invoicePdfUrl,
    this.etimsStatus,
    this.etimsNo,
    this.etimsUrl,
    this.submittedAt,
    this.submittedByUid,
    this.status,
    this.isActive,
  });

  final String membershipId;

  final String invoiceId;
  final String? invoiceNumber;

  final String? authCode;
  final String? claimNo;
  final String? visitNo;
  final String? serviceDate;

  final String? prescriptionNo;
  final String? prescriberName;

  final String? prescriptionId;
  final String? prescriptionFileName;
  final String? prescriptionUrl;
  final String? prescriptionStoragePath;

  final String? diagnosis;
  final String? icd10Code;
  final String? investigations;
  final String? treatmentRecommendations;
  final String? notes;

  final ClaimFormStatus? claimFormStatus;
  final String? claimFormUrl;
  final String? claimFormFileName;
  final String? claimFormStoragePath;
  final String? claimFormOriginalStoragePath;
  final String? claimFormThumbnailStoragePath;
  final String? claimFormContentType;
  final int? claimFormSizeBytes;

  final String? invoicePdfUrl;

  final EtimsStatus? etimsStatus;
  final String? etimsNo;
  final String? etimsUrl;

  final String? submittedAt;
  final String? submittedByUid;

  final InsuranceClaimStatus? status;
  final bool? isActive;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'membership_id': membershipId,
      'invoice_id': invoiceId,
      'invoice_number': invoiceNumber,
      'auth_code': authCode,
      'claim_no': claimNo,
      'visit_no': visitNo,
      'service_date': serviceDate,
      'prescription_no': prescriptionNo,
      'prescriber_name': prescriberName,
      'prescription_id': prescriptionId,
      'prescription_file_name': prescriptionFileName,
      'prescription_url': prescriptionUrl,
      'prescription_storage_path': prescriptionStoragePath,
      'diagnosis': diagnosis,
      'icd10_code': icd10Code,
      'investigations': investigations,
      'treatment_recommendations': treatmentRecommendations,
      'notes': notes,
      'claim_form_status': claimFormStatus?.wire,
      'claim_form_url': claimFormUrl,
      'claim_form_file_name': claimFormFileName,
      'claim_form_storage_path': claimFormStoragePath,
      'claim_form_original_storage_path': claimFormOriginalStoragePath,
      'claim_form_thumbnail_storage_path': claimFormThumbnailStoragePath,
      'claim_form_content_type': claimFormContentType,
      'claim_form_size_bytes': claimFormSizeBytes,
      'invoice_pdf_url': invoicePdfUrl,
      'etims_status': etimsStatus?.wire,
      'etims_no': etimsNo,
      'etims_url': etimsUrl,
      'submitted_at': submittedAt,
      'submitted_by_uid': submittedByUid,
      'status': status?.wire,
      'is_active': isActive,
    }..removeWhere(_removeEmpty);
  }

  static bool _removeEmpty(Object? _, Object? value) {
    if (value == null) return true;
    if (value is String && value.trim().isEmpty) return true;
    return false;
  }
}
