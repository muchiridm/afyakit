// lib/features/patients/models/patient_profile.dart

import 'package:flutter/foundation.dart';

@immutable
class PatientProfile {
  const PatientProfile({
    required this.patientId,
    required this.fullName,
    required this.dob,
    required this.memberNumber,
    required this.insurance,
    required this.scheme,
    required this.payerContactId,
    required this.isActive,
    this.payerDisplayName,
    this.phone,
    this.email,
    this.nationalId,
    this.policyNumber,
    this.principalMemberName,
    this.relationshipToPrincipal,
    this.authorizationNumber,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String patientId;
  final String fullName;
  final String dob; // YYYY-MM-DD
  final String memberNumber;

  final String insurance;
  final String scheme;

  final String payerContactId;
  final String? payerDisplayName;

  final String? phone;
  final String? email;
  final String? nationalId;
  final String? policyNumber;
  final String? principalMemberName;
  final String? relationshipToPrincipal;
  final String? authorizationNumber;
  final String? notes;

  final bool isActive;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  static String? _readNullableString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  static bool _readBool(
    Map<String, Object?> json,
    String key, {
    bool fallback = false,
  }) {
    final value = json[key];
    if (value is bool) return value;
    if (value is String) {
      final s = value.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no') return false;
    }
    return fallback;
  }

  static DateTime? _readDateTime(Map<String, Object?> json, String key) {
    final raw = _readNullableString(json, key);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static String _readRequiredString(Map<String, Object?> json, String key) {
    final value = _readNullableString(json, key);
    if (value == null) {
      throw FormatException('Missing required field: $key');
    }
    return value;
  }

  factory PatientProfile.fromJson(Map<String, Object?> json) {
    return PatientProfile(
      patientId: _readRequiredString(json, 'patient_id'),
      fullName: _readRequiredString(json, 'full_name'),
      dob: _readRequiredString(json, 'dob'),
      memberNumber: _readRequiredString(json, 'member_number'),
      insurance: _readRequiredString(json, 'insurance'),
      scheme: _readRequiredString(json, 'scheme'),
      payerContactId: _readRequiredString(json, 'payer_contact_id'),
      payerDisplayName: _readNullableString(json, 'payer_display_name'),
      phone: _readNullableString(json, 'phone'),
      email: _readNullableString(json, 'email'),
      nationalId: _readNullableString(json, 'national_id'),
      policyNumber: _readNullableString(json, 'policy_number'),
      principalMemberName: _readNullableString(json, 'principal_member_name'),
      relationshipToPrincipal: _readNullableString(
        json,
        'relationship_to_principal',
      ),
      authorizationNumber: _readNullableString(json, 'authorization_number'),
      notes: _readNullableString(json, 'notes'),
      isActive: _readBool(json, 'is_active', fallback: true),
      createdAt: _readDateTime(json, 'created_at'),
      updatedAt: _readDateTime(json, 'updated_at'),
    );
  }

  PatientProfile copyWith({
    String? patientId,
    String? fullName,
    String? dob,
    String? memberNumber,
    String? insurance,
    String? scheme,
    String? payerContactId,
    String? payerDisplayName,
    String? phone,
    String? email,
    String? nationalId,
    String? policyNumber,
    String? principalMemberName,
    String? relationshipToPrincipal,
    String? authorizationNumber,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PatientProfile(
      patientId: patientId ?? this.patientId,
      fullName: fullName ?? this.fullName,
      dob: dob ?? this.dob,
      memberNumber: memberNumber ?? this.memberNumber,
      insurance: insurance ?? this.insurance,
      scheme: scheme ?? this.scheme,
      payerContactId: payerContactId ?? this.payerContactId,
      payerDisplayName: payerDisplayName ?? this.payerDisplayName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      nationalId: nationalId ?? this.nationalId,
      policyNumber: policyNumber ?? this.policyNumber,
      principalMemberName: principalMemberName ?? this.principalMemberName,
      relationshipToPrincipal:
          relationshipToPrincipal ?? this.relationshipToPrincipal,
      authorizationNumber: authorizationNumber ?? this.authorizationNumber,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
class PatientProfileUpsertInput {
  const PatientProfileUpsertInput({
    required this.fullName,
    required this.dob,
    required this.memberNumber,
    required this.insurance,
    required this.scheme,
    required this.payerContactId,
    this.phone,
    this.email,
    this.nationalId,
    this.policyNumber,
    this.principalMemberName,
    this.relationshipToPrincipal,
    this.authorizationNumber,
    this.notes,
    this.isActive = true,
  });

  final String fullName;
  final String dob;
  final String memberNumber;

  final String insurance;
  final String scheme;

  final String payerContactId;

  final String? phone;
  final String? email;
  final String? nationalId;
  final String? policyNumber;
  final String? principalMemberName;
  final String? relationshipToPrincipal;
  final String? authorizationNumber;
  final String? notes;

  final bool isActive;

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'full_name': fullName.trim(),
      'dob': dob.trim(),
      'member_number': memberNumber.trim(),
      'insurance': insurance.trim(),
      'scheme': scheme.trim(),
      'payer_contact_id': payerContactId.trim(),
      'phone': _nullable(phone),
      'email': _nullable(email),
      'national_id': _nullable(nationalId),
      'policy_number': _nullable(policyNumber),
      'principal_member_name': _nullable(principalMemberName),
      'relationship_to_principal': _nullable(relationshipToPrincipal),
      'authorization_number': _nullable(authorizationNumber),
      'notes': _nullable(notes),
      'is_active': isActive,
    };
  }

  factory PatientProfileUpsertInput.fromProfile(PatientProfile profile) {
    return PatientProfileUpsertInput(
      fullName: profile.fullName,
      dob: profile.dob,
      memberNumber: profile.memberNumber,
      insurance: profile.insurance,
      scheme: profile.scheme,
      payerContactId: profile.payerContactId,
      phone: profile.phone,
      email: profile.email,
      nationalId: profile.nationalId,
      policyNumber: profile.policyNumber,
      principalMemberName: profile.principalMemberName,
      relationshipToPrincipal: profile.relationshipToPrincipal,
      authorizationNumber: profile.authorizationNumber,
      notes: profile.notes,
      isActive: profile.isActive,
    );
  }
}
