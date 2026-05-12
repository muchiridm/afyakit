// lib/features/insurance/memberships/models/insurance_membership.dart

class InsuranceMembership {
  const InsuranceMembership({
    required this.membershipId,
    required this.patientId,
    this.patientNo,
    this.patientDisplayName,
    required this.payerContactId,
    this.payerAccountNumber,
    this.payerDisplayName,
    required this.memberNumber,
    this.memberName,
    this.principalName,
    this.scheme,
    this.medicalCardNumber,
    this.policyNumber,
    this.providerCode,
    this.providerName,
    this.effectiveFrom,
    this.effectiveTo,
    this.notes,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  final String membershipId;

  final String patientId;
  final String? patientNo;
  final String? patientDisplayName;

  final String payerContactId;
  final String? payerAccountNumber;
  final String? payerDisplayName;

  final String memberNumber;
  final String? memberName;
  final String? principalName;

  final String? scheme;
  final String? medicalCardNumber;
  final String? policyNumber;

  final String? providerCode;
  final String? providerName;

  final String? effectiveFrom;
  final String? effectiveTo;

  final String? notes;
  final bool isActive;

  final String? createdAt;
  final String? updatedAt;

  String get displayTitle {
    final patient = patientDisplayName?.trim() ?? '';
    final member = memberNumber.trim();

    if (patient.isNotEmpty && member.isNotEmpty) {
      return '$patient · $member';
    }

    if (patient.isNotEmpty) return patient;
    if (member.isNotEmpty) return member;

    return membershipId;
  }

  String get payerLabel {
    final payer = payerDisplayName?.trim() ?? '';
    if (payer.isNotEmpty) return payer;
    return payerContactId;
  }

  factory InsuranceMembership.fromJson(Map<String, Object?> json) {
    return InsuranceMembership(
      membershipId: _s(json['membership_id']),
      patientId: _s(json['patient_id']),
      patientNo: _sn(json['patient_no']),
      patientDisplayName: _sn(json['patient_display_name']),
      payerContactId: _s(json['payer_contact_id']),
      payerAccountNumber: _sn(json['payer_account_number']),
      payerDisplayName: _sn(json['payer_display_name']),
      memberNumber: _s(json['member_number']),
      memberName: _sn(json['member_name']),
      principalName: _sn(json['principal_name']),
      scheme: _sn(json['scheme']),
      medicalCardNumber: _sn(json['medical_card_number']),
      policyNumber: _sn(json['policy_number']),
      providerCode: _sn(json['provider_code']),
      providerName: _sn(json['provider_name']),
      effectiveFrom: _sn(json['effective_from']),
      effectiveTo: _sn(json['effective_to']),
      notes: _sn(json['notes']),
      isActive: json['is_active'] == true,
      createdAt: _sn(json['created_at']),
      updatedAt: _sn(json['updated_at']),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'membership_id': membershipId,
      'patient_id': patientId,
      'patient_no': patientNo,
      'patient_display_name': patientDisplayName,
      'payer_contact_id': payerContactId,
      'payer_account_number': payerAccountNumber,
      'payer_display_name': payerDisplayName,
      'member_number': memberNumber,
      'member_name': memberName,
      'principal_name': principalName,
      'scheme': scheme,
      'medical_card_number': medicalCardNumber,
      'policy_number': policyNumber,
      'provider_code': providerCode,
      'provider_name': providerName,
      'effective_from': effectiveFrom,
      'effective_to': effectiveTo,
      'notes': notes,
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

class InsuranceMembershipUpsertInput {
  const InsuranceMembershipUpsertInput({
    required this.patientId,
    required this.payerContactId,
    this.payerAccountNumber,
    this.payerDisplayName,
    required this.memberNumber,
    this.memberName,
    this.principalName,
    this.scheme,
    this.medicalCardNumber,
    this.policyNumber,
    this.providerCode,
    this.providerName,
    this.effectiveFrom,
    this.effectiveTo,
    this.notes,
    this.isActive,
  });

  final String patientId;

  final String payerContactId;
  final String? payerAccountNumber;
  final String? payerDisplayName;

  final String memberNumber;
  final String? memberName;
  final String? principalName;

  final String? scheme;
  final String? medicalCardNumber;
  final String? policyNumber;

  final String? providerCode;
  final String? providerName;

  final String? effectiveFrom;
  final String? effectiveTo;

  final String? notes;
  final bool? isActive;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'patient_id': patientId,
      'payer_contact_id': payerContactId,
      'payer_account_number': payerAccountNumber,
      'payer_display_name': payerDisplayName,
      'member_number': memberNumber,
      'member_name': memberName,
      'principal_name': principalName,
      'scheme': scheme,
      'medical_card_number': medicalCardNumber,
      'policy_number': policyNumber,
      'provider_code': providerCode,
      'provider_name': providerName,
      'effective_from': effectiveFrom,
      'effective_to': effectiveTo,
      'notes': notes,
      'is_active': isActive,
    }..removeWhere(_removeEmpty);
  }

  static bool _removeEmpty(Object? _, Object? value) {
    if (value == null) return true;
    if (value is String && value.trim().isEmpty) return true;
    return false;
  }
}
