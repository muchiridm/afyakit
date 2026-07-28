// lib/features/clinical/patients/patient_profile.dart

import 'package:flutter/foundation.dart';

enum ContactPatientRelationship {
  self,
  child,
  spouse,
  parent,
  guardian,
  other;

  static ContactPatientRelationship fromJson(Object? value) {
    final raw = value?.toString().trim().toLowerCase();

    return ContactPatientRelationship.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => ContactPatientRelationship.other,
    );
  }
}

enum PatientGender {
  male,
  female,
  other,
  unknown;

  static PatientGender fromJson(Object? value) {
    final raw = value?.toString().trim().toLowerCase();

    return PatientGender.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => PatientGender.unknown,
    );
  }
}

@immutable
class PatientProfile {
  const PatientProfile({
    required this.patientId,
    required this.fullName,
    required this.isActive,
    this.dob,
    this.gender,
    this.phone,
    this.email,
    this.nationalId,
    this.notes,
    this.linkId,
    this.contactId,
    this.contactDisplayName,
    this.relationship,
    this.createdAt,
    this.updatedAt,
  });

  final String patientId;
  final String fullName;
  final String? dob;
  final PatientGender? gender;

  final String? phone;
  final String? email;
  final String? nationalId;
  final String? notes;

  final bool isActive;

  final String? linkId;
  final String? contactId;
  final String? contactDisplayName;
  final ContactPatientRelationship? relationship;

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
    final relationshipRaw = _readNullableString(json, 'relationship');
    final genderRaw = _readNullableString(json, 'gender');

    return PatientProfile(
      patientId: _readRequiredString(json, 'patient_id'),
      fullName: _readRequiredString(json, 'full_name'),
      dob: _readNullableString(json, 'dob'),
      gender: genderRaw == null ? null : PatientGender.fromJson(genderRaw),
      phone: _readNullableString(json, 'phone'),
      email: _readNullableString(json, 'email'),
      nationalId: _readNullableString(json, 'national_id'),
      notes: _readNullableString(json, 'notes'),
      isActive: _readBool(json, 'is_active', fallback: true),
      linkId: _readNullableString(json, 'link_id'),
      contactId: _readNullableString(json, 'contact_id'),
      contactDisplayName: _readNullableString(json, 'contact_display_name'),
      relationship: relationshipRaw == null
          ? null
          : ContactPatientRelationship.fromJson(relationshipRaw),
      createdAt: _readDateTime(json, 'created_at'),
      updatedAt: _readDateTime(json, 'updated_at'),
    );
  }

  PatientProfile copyWith({
    String? patientId,
    String? fullName,
    String? dob,
    PatientGender? gender,
    String? phone,
    String? email,
    String? nationalId,
    String? notes,
    bool? isActive,
    String? linkId,
    String? contactId,
    String? contactDisplayName,
    ContactPatientRelationship? relationship,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PatientProfile(
      patientId: patientId ?? this.patientId,
      fullName: fullName ?? this.fullName,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      nationalId: nationalId ?? this.nationalId,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      linkId: linkId ?? this.linkId,
      contactId: contactId ?? this.contactId,
      contactDisplayName: contactDisplayName ?? this.contactDisplayName,
      relationship: relationship ?? this.relationship,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
class PatientProfileUpsertInput {
  const PatientProfileUpsertInput({
    required this.fullName,
    this.dob,
    this.gender = PatientGender.unknown,
    this.contactId,
    this.relationship = ContactPatientRelationship.self,
    this.phone,
    this.email,
    this.nationalId,
    this.notes,
    this.isActive = true,
  });

  final String fullName;
  final String? dob;
  final PatientGender gender;
  final String? contactId;
  final ContactPatientRelationship relationship;
  final String? phone;
  final String? email;
  final String? nationalId;
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
      'dob': _nullable(dob),
      'gender': gender.name,
      'contact_id': _nullable(contactId),
      'relationship': relationship.name,
      'phone': _nullable(phone),
      'email': _nullable(email),
      'national_id': _nullable(nationalId),
      'notes': _nullable(notes),
      'is_active': isActive,
    };
  }

  factory PatientProfileUpsertInput.fromProfile(PatientProfile profile) {
    return PatientProfileUpsertInput(
      fullName: profile.fullName,
      dob: profile.dob,
      gender: profile.gender ?? PatientGender.unknown,
      contactId: profile.contactId,
      relationship: profile.relationship ?? ContactPatientRelationship.self,
      phone: profile.phone,
      email: profile.email,
      nationalId: profile.nationalId,
      notes: profile.notes,
      isActive: profile.isActive,
    );
  }
}

@immutable
class PatientProfileLinkToSelfInput {
  const PatientProfileLinkToSelfInput({
    this.relationship = ContactPatientRelationship.self,
    this.confirmFullName,
    this.confirmGender,
    this.confirmDob,
    this.confirmPhone,
    this.confirmEmail,
    this.confirmNationalId,
  });

  final ContactPatientRelationship relationship;
  final String? confirmFullName;
  final PatientGender? confirmGender;
  final String? confirmDob;
  final String? confirmPhone;
  final String? confirmEmail;
  final String? confirmNationalId;

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'relationship': relationship.name,
      'confirm_full_name': _nullable(confirmFullName),
      'confirm_gender': confirmGender?.name,
      'confirm_dob': _nullable(confirmDob),
      'confirm_phone': _nullable(confirmPhone),
      'confirm_email': _nullable(confirmEmail),
      'confirm_national_id': _nullable(confirmNationalId),
    };
  }
}
