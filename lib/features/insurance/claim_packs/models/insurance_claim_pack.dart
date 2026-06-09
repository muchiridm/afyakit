// lib/features/insurance/claim_packs/models/insurance_claim_pack.dart

enum InsuranceClaimPackStatus {
  draft,
  pendingReview,
  ready,
  submitted,
  approved,
  paid,
  rejected,
  cancelled,
}

extension InsuranceClaimPackStatusX on InsuranceClaimPackStatus {
  String get wire {
    switch (this) {
      case InsuranceClaimPackStatus.draft:
        return 'draft';
      case InsuranceClaimPackStatus.pendingReview:
        return 'pending_review';
      case InsuranceClaimPackStatus.ready:
        return 'ready';
      case InsuranceClaimPackStatus.submitted:
        return 'submitted';
      case InsuranceClaimPackStatus.approved:
        return 'approved';
      case InsuranceClaimPackStatus.paid:
        return 'paid';
      case InsuranceClaimPackStatus.rejected:
        return 'rejected';
      case InsuranceClaimPackStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case InsuranceClaimPackStatus.draft:
        return 'Draft';
      case InsuranceClaimPackStatus.pendingReview:
        return 'Pending Review';
      case InsuranceClaimPackStatus.ready:
        return 'Ready';
      case InsuranceClaimPackStatus.submitted:
        return 'Submitted';
      case InsuranceClaimPackStatus.approved:
        return 'Approved';
      case InsuranceClaimPackStatus.paid:
        return 'Paid';
      case InsuranceClaimPackStatus.rejected:
        return 'Rejected';
      case InsuranceClaimPackStatus.cancelled:
        return 'Cancelled';
    }
  }

  static InsuranceClaimPackStatus fromWire(Object? value) {
    final String s = _cleanString(value);

    for (final InsuranceClaimPackStatus status
        in InsuranceClaimPackStatus.values) {
      if (status.wire == s) return status;
    }

    return InsuranceClaimPackStatus.draft;
  }
}

class InsuranceClaimPack {
  const InsuranceClaimPack({
    required this.claimPackId,
    required this.patientId,
    required this.membershipId,
    this.invoiceId,
    this.invoiceNumber,
    this.prescriptionId,
    this.prescriptionNo,
    this.prescriberName,
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
    this.authCode,
    this.insurerClaimNo,
    this.visitNo,
    this.serviceDate,
    this.diagnosis,
    this.icd10Code,
    this.notes,
    this.submittedAt,
    this.submittedByUid,
    required this.status,
    required this.isActive,
    this.createdByUid,
    this.createdAt,
    this.updatedAt,
  });

  final String claimPackId;

  final String patientId;
  final String membershipId;

  final String? invoiceId;
  final String? invoiceNumber;

  final String? prescriptionId;
  final String? prescriptionNo;
  final String? prescriberName;

  final String? patientNo;
  final String? patientDisplayName;

  final String? payerContactId;
  final String? payerDisplayName;

  final String? memberNo;
  final String? medicalCardNo;
  final String? policyNo;

  final String? memberName;
  final String? principalName;
  final String? scheme;

  final String? authCode;
  final String? insurerClaimNo;
  final String? visitNo;
  final String? serviceDate;

  final String? diagnosis;
  final String? icd10Code;
  final String? notes;

  final String? submittedAt;
  final String? submittedByUid;

  final InsuranceClaimPackStatus status;
  final bool isActive;

  final String? createdByUid;
  final String? createdAt;
  final String? updatedAt;

  bool get hasInvoice => _hasText(invoiceId) || _hasText(invoiceNumber);

  bool get hasPrescription =>
      _hasText(prescriptionId) || _hasText(prescriptionNo);

  bool get hasMembership => _hasText(membershipId);

  factory InsuranceClaimPack.fromJson(Map<String, Object?> json) {
    return InsuranceClaimPack(
      claimPackId: _s(json['claim_pack_id']),
      patientId: _s(json['patient_id']),
      membershipId: _s(json['membership_id']),
      invoiceId: _sn(json['invoice_id']),
      invoiceNumber: _sn(json['invoice_number']),
      prescriptionId: _sn(json['prescription_id']),
      prescriptionNo: _sn(json['prescription_no']),
      prescriberName: _sn(json['prescriber_name']),
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
      authCode: _sn(json['auth_code']),
      insurerClaimNo: _sn(json['insurer_claim_no']),
      visitNo: _sn(json['visit_no']),
      serviceDate: _sn(json['service_date']),
      diagnosis: _sn(json['diagnosis']),
      icd10Code: _sn(json['icd10_code']),
      notes: _sn(json['notes']),
      submittedAt: _sn(json['submitted_at']),
      submittedByUid: _sn(json['submitted_by_uid']),
      status: InsuranceClaimPackStatusX.fromWire(json['status']),
      isActive: json['is_active'] != false,
      createdByUid: _sn(json['created_by_uid']),
      createdAt: _sn(json['created_at']),
      updatedAt: _sn(json['updated_at']),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'claim_pack_id': claimPackId,
      'patient_id': patientId,
      'membership_id': membershipId,
      'invoice_id': invoiceId,
      'invoice_number': invoiceNumber,
      'prescription_id': prescriptionId,
      'prescription_no': prescriptionNo,
      'prescriber_name': prescriberName,
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
      'auth_code': authCode,
      'insurer_claim_no': insurerClaimNo,
      'visit_no': visitNo,
      'service_date': serviceDate,
      'diagnosis': diagnosis,
      'icd10_code': icd10Code,
      'notes': notes,
      'submitted_at': submittedAt,
      'submitted_by_uid': submittedByUid,
      'status': status.wire,
      'is_active': isActive,
      'created_by_uid': createdByUid,
      'created_at': createdAt,
      'updated_at': updatedAt,
    }..removeWhere(_removeEmpty);
  }
}

class InsuranceClaimPackCreateInput {
  const InsuranceClaimPackCreateInput({
    required this.membershipId,
    this.invoiceId,
    this.invoiceNumber,
    this.prescriptionId,
    this.prescriptionNo,
    this.prescriberName,
    this.authCode,
    this.insurerClaimNo,
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

  final String? invoiceId;
  final String? invoiceNumber;

  final String? prescriptionId;
  final String? prescriptionNo;
  final String? prescriberName;

  final String? authCode;
  final String? insurerClaimNo;
  final String? visitNo;
  final String? serviceDate;

  final String? diagnosis;
  final String? icd10Code;
  final String? notes;

  final String? submittedAt;
  final String? submittedByUid;

  final InsuranceClaimPackStatus? status;
  final bool? isActive;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'membership_id': membershipId,
      'invoice_id': invoiceId,
      'invoice_number': invoiceNumber,
      'prescription_id': prescriptionId,
      'prescription_no': prescriptionNo,
      'prescriber_name': prescriberName,
      'auth_code': authCode,
      'insurer_claim_no': insurerClaimNo,
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

class InsuranceClaimPackUpdateInput {
  const InsuranceClaimPackUpdateInput({
    this.membershipId,
    this.invoiceId,
    this.invoiceNumber,
    this.prescriptionId,
    this.prescriptionNo,
    this.prescriberName,
    this.authCode,
    this.insurerClaimNo,
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

  final String? invoiceId;
  final String? invoiceNumber;

  final String? prescriptionId;
  final String? prescriptionNo;
  final String? prescriberName;

  final String? authCode;
  final String? insurerClaimNo;
  final String? visitNo;
  final String? serviceDate;

  final String? diagnosis;
  final String? icd10Code;
  final String? notes;

  final String? submittedAt;
  final String? submittedByUid;

  final InsuranceClaimPackStatus? status;
  final bool? isActive;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'membership_id': membershipId,
      'invoice_id': invoiceId,
      'invoice_number': invoiceNumber,
      'prescription_id': prescriptionId,
      'prescription_no': prescriptionNo,
      'prescriber_name': prescriberName,
      'auth_code': authCode,
      'insurer_claim_no': insurerClaimNo,
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
