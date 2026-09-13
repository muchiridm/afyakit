// lib/features/insurance/memberships/models/insurance_membership.dart

class InsuranceMembership {
  const InsuranceMembership({
    required this.membershipId,
    required this.profileId,
    this.patientNo,
    this.profileDisplayName,
    required this.payerContactId,
    this.payerAccountNumber,
    this.payerDisplayName,
    required this.memberNo,
    this.memberName,
    this.principalName,
    this.scheme,
    this.medicalCardNo,
    this.policyNo,
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

  final String profileId;
  final String? patientNo;
  final String? profileDisplayName;

  final String payerContactId;
  final String? payerAccountNumber;
  final String? payerDisplayName;

  final String memberNo;
  final String? memberName;
  final String? principalName;

  final String? scheme;
  final String? medicalCardNo;
  final String? policyNo;

  final String? providerCode;
  final String? providerName;

  final String? effectiveFrom;
  final String? effectiveTo;

  final String? notes;
  final bool isActive;

  final String? createdAt;
  final String? updatedAt;

  String get displayTitle {
    final profile = profileDisplayName?.trim() ?? '';
    final member = memberNo.trim();

    if (profile.isNotEmpty && member.isNotEmpty) {
      return '$profile · $member';
    }

    if (profile.isNotEmpty) return profile;
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
      profileId: _s(json['profile_id']),
      patientNo: _sn(json['patient_no']),
      profileDisplayName: _sn(json['profile_display_name']),
      payerContactId: _s(json['payer_contact_id']),
      payerAccountNumber: _sn(json['payer_account_number']),
      payerDisplayName: _sn(json['payer_display_name']),
      memberNo: _s(json['member_no']),
      memberName: _sn(json['member_name']),
      principalName: _sn(json['principal_name']),
      scheme: _sn(json['scheme']),
      medicalCardNo: _sn(json['medical_card_no']),
      policyNo: _sn(json['policy_no']),
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
      'profile_id': profileId,
      'patient_no': patientNo,
      'profile_display_name': profileDisplayName,
      'payer_contact_id': payerContactId,
      'payer_account_number': payerAccountNumber,
      'payer_display_name': payerDisplayName,
      'member_no': memberNo,
      'member_name': memberName,
      'principal_name': principalName,
      'scheme': scheme,
      'medical_card_no': medicalCardNo,
      'policy_no': policyNo,
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
    required this.profileId,
    required this.payerContactId,
    this.payerAccountNumber,
    this.payerDisplayName,
    required this.memberNo,
    this.memberName,
    this.principalName,
    this.scheme,
    this.medicalCardNo,
    this.policyNo,
    this.providerCode,
    this.providerName,
    this.effectiveFrom,
    this.effectiveTo,
    this.notes,
    this.isActive,
  });

  final String profileId;

  final String payerContactId;
  final String? payerAccountNumber;
  final String? payerDisplayName;

  final String memberNo;
  final String? memberName;
  final String? principalName;

  final String? scheme;
  final String? medicalCardNo;
  final String? policyNo;

  final String? providerCode;
  final String? providerName;

  final String? effectiveFrom;
  final String? effectiveTo;

  final String? notes;
  final bool? isActive;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'profile_id': profileId,
      'payer_contact_id': payerContactId,
      'payer_account_number': payerAccountNumber,
      'payer_display_name': payerDisplayName,
      'member_no': memberNo,
      'member_name': memberName,
      'principal_name': principalName,
      'scheme': scheme,
      'medical_card_no': medicalCardNo,
      'policy_no': policyNo,
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
