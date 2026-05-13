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
    this.diagnosis,
    this.icd10Code,
    this.investigations,
    this.treatmentRecommendations,
    this.notes,
    this.claimFormStatus,
    this.claimFormUrl,
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
  final String? prescriptionNo;
  final String? prescriberName;

  final String? diagnosis;
  final String? icd10Code;
  final String? investigations;
  final String? treatmentRecommendations;
  final String? notes;

  final ClaimFormStatus? claimFormStatus;
  final String? claimFormUrl;

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

  /// Temporary compatibility getters for older UI code.
  @Deprecated('Use memberNo instead.')
  String get memberNumber => memberNo;

  @Deprecated('Use medicalCardNo instead.')
  String? get medicalCardNumber => medicalCardNo;

  @Deprecated('Use policyNo instead.')
  String? get policyNumber => policyNo;

  @Deprecated('Use authCode instead.')
  String? get authorizationNumber => authCode;

  @Deprecated('Use claimNo instead.')
  String? get claimNumber => claimNo;

  @Deprecated('Use visitNo instead.')
  String? get visitNumber => visitNo;

  @Deprecated('Use prescriptionNo instead.')
  String? get prescriptionNumber => prescriptionNo;

  @Deprecated('Use etimsNo instead.')
  String? get etimsNumber => etimsNo;

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
      diagnosis: _sn(json['diagnosis']),
      icd10Code: _sn(json['icd10_code']),
      investigations: _sn(json['investigations']),
      treatmentRecommendations: _sn(json['treatment_recommendations']),
      notes: _sn(json['notes']),
      claimFormStatus: json.containsKey('claim_form_status')
          ? ClaimFormStatusX.fromWire(json['claim_form_status'])
          : null,
      claimFormUrl: _sn(json['claim_form_url']),
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
      'diagnosis': diagnosis,
      'icd10_code': icd10Code,
      'investigations': investigations,
      'treatment_recommendations': treatmentRecommendations,
      'notes': notes,
      'claim_form_status': claimFormStatus?.wire,
      'claim_form_url': claimFormUrl,
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
    this.diagnosis,
    this.icd10Code,
    this.investigations,
    this.treatmentRecommendations,
    this.notes,
    this.claimFormStatus,
    this.claimFormUrl,
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

  final String? diagnosis;
  final String? icd10Code;
  final String? investigations;
  final String? treatmentRecommendations;
  final String? notes;

  final ClaimFormStatus? claimFormStatus;
  final String? claimFormUrl;

  final String? invoicePdfUrl;

  final EtimsStatus? etimsStatus;
  final String? etimsNo;
  final String? etimsUrl;

  final String? submittedAt;
  final String? submittedByUid;

  final InsuranceClaimStatus? status;
  final bool? isActive;

  @Deprecated(
    'Use authCode, claimNo, visitNo, prescriptionNo and etimsNo instead.',
  )
  factory InsuranceClaimUpsertInput.legacy({
    required String membershipId,
    required String invoiceId,
    String? invoiceNumber,
    String? authorizationNumber,
    String? claimNumber,
    String? visitNumber,
    String? serviceDate,
    String? prescriptionNumber,
    String? prescriberName,
    String? diagnosis,
    String? icd10Code,
    String? investigations,
    String? treatmentRecommendations,
    String? notes,
    ClaimFormStatus? claimFormStatus,
    String? claimFormUrl,
    String? invoicePdfUrl,
    EtimsStatus? etimsStatus,
    String? etimsNumber,
    String? etimsUrl,
    String? submittedAt,
    String? submittedByUid,
    InsuranceClaimStatus? status,
    bool? isActive,
  }) {
    return InsuranceClaimUpsertInput(
      membershipId: membershipId,
      invoiceId: invoiceId,
      invoiceNumber: invoiceNumber,
      authCode: authorizationNumber,
      claimNo: claimNumber,
      visitNo: visitNumber,
      serviceDate: serviceDate,
      prescriptionNo: prescriptionNumber,
      prescriberName: prescriberName,
      diagnosis: diagnosis,
      icd10Code: icd10Code,
      investigations: investigations,
      treatmentRecommendations: treatmentRecommendations,
      notes: notes,
      claimFormStatus: claimFormStatus,
      claimFormUrl: claimFormUrl,
      invoicePdfUrl: invoicePdfUrl,
      etimsStatus: etimsStatus,
      etimsNo: etimsNumber,
      etimsUrl: etimsUrl,
      submittedAt: submittedAt,
      submittedByUid: submittedByUid,
      status: status,
      isActive: isActive,
    );
  }

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
      'diagnosis': diagnosis,
      'icd10_code': icd10Code,
      'investigations': investigations,
      'treatment_recommendations': treatmentRecommendations,
      'notes': notes,
      'claim_form_status': claimFormStatus?.wire,
      'claim_form_url': claimFormUrl,
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
