// lib/features/insurance/claims/models/insurance_claim.dart

enum InsuranceClaimStatus {
  draft,
  ready,
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
    required this.memberNumber,
    this.memberName,
    this.principalName,
    this.scheme,
    this.medicalCardNumber,
    this.policyNumber,
    this.authorizationNumber,
    this.claimNumber,
    this.visitNumber,
    this.serviceDate,
    this.prescriptionNumber,
    this.prescriberName,
    this.diagnosis,
    this.icd10Code,
    this.investigations,
    this.treatmentRecommendations,
    this.notes,
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

  final String memberNumber;
  final String? memberName;
  final String? principalName;

  final String? scheme;
  final String? medicalCardNumber;
  final String? policyNumber;

  final String? authorizationNumber;
  final String? claimNumber;
  final String? visitNumber;
  final String? serviceDate;
  final String? prescriptionNumber;
  final String? prescriberName;

  final String? diagnosis;
  final String? icd10Code;
  final String? investigations;
  final String? treatmentRecommendations;
  final String? notes;

  final InsuranceClaimStatus status;
  final bool isActive;

  final String? createdAt;
  final String? updatedAt;

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
      memberNumber: _s(json['member_number']),
      memberName: _sn(json['member_name']),
      principalName: _sn(json['principal_name']),
      scheme: _sn(json['scheme']),
      medicalCardNumber: _sn(json['medical_card_number']),
      policyNumber: _sn(json['policy_number']),
      authorizationNumber: _sn(json['authorization_number']),
      claimNumber: _sn(json['claim_number']),
      visitNumber: _sn(json['visit_number']),
      serviceDate: _sn(json['service_date']),
      prescriptionNumber: _sn(json['prescription_number']),
      prescriberName: _sn(json['prescriber_name']),
      diagnosis: _sn(json['diagnosis']),
      icd10Code: _sn(json['icd10_code']),
      investigations: _sn(json['investigations']),
      treatmentRecommendations: _sn(json['treatment_recommendations']),
      notes: _sn(json['notes']),
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
      'member_number': memberNumber,
      'member_name': memberName,
      'principal_name': principalName,
      'scheme': scheme,
      'medical_card_number': medicalCardNumber,
      'policy_number': policyNumber,
      'authorization_number': authorizationNumber,
      'claim_number': claimNumber,
      'visit_number': visitNumber,
      'service_date': serviceDate,
      'prescription_number': prescriptionNumber,
      'prescriber_name': prescriberName,
      'diagnosis': diagnosis,
      'icd10_code': icd10Code,
      'investigations': investigations,
      'treatment_recommendations': treatmentRecommendations,
      'notes': notes,
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
    this.authorizationNumber,
    this.claimNumber,
    this.visitNumber,
    this.serviceDate,
    this.prescriptionNumber,
    this.prescriberName,
    this.diagnosis,
    this.icd10Code,
    this.investigations,
    this.treatmentRecommendations,
    this.notes,
    this.status,
    this.isActive,
  });

  final String membershipId;

  final String invoiceId;
  final String? invoiceNumber;

  final String? authorizationNumber;
  final String? claimNumber;
  final String? visitNumber;
  final String? serviceDate;
  final String? prescriptionNumber;
  final String? prescriberName;

  final String? diagnosis;
  final String? icd10Code;
  final String? investigations;
  final String? treatmentRecommendations;
  final String? notes;

  final InsuranceClaimStatus? status;
  final bool? isActive;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'membership_id': membershipId,
      'invoice_id': invoiceId,
      'invoice_number': invoiceNumber,
      'authorization_number': authorizationNumber,
      'claim_number': claimNumber,
      'visit_number': visitNumber,
      'service_date': serviceDate,
      'prescription_number': prescriptionNumber,
      'prescriber_name': prescriberName,
      'diagnosis': diagnosis,
      'icd10_code': icd10Code,
      'investigations': investigations,
      'treatment_recommendations': treatmentRecommendations,
      'notes': notes,
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
