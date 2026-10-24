// lib/features/records/health_profiles/profile_models.dart

import 'package:flutter/foundation.dart';

enum ProfileContactRelationship {
  self,
  child,
  spouse,
  parent,
  guardian,
  insurance,
  other;

  static ProfileContactRelationship fromJson(Object? value) {
    final raw = value?.toString().trim().toLowerCase();

    return ProfileContactRelationship.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => ProfileContactRelationship.other,
    );
  }
}

enum ProfileGender {
  male,
  female,
  other,
  unknown;

  static ProfileGender fromJson(Object? value) {
    final raw = value?.toString().trim().toLowerCase();

    return ProfileGender.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => ProfileGender.unknown,
    );
  }
}

// The classification values remain controlled; each patient may have any number of
// allergy, vaccination and condition records. Backend validation must match.
enum AllergyStatus { unknown, none_known, known }

enum AllergyCategory { drug, food, environmental, other }

enum AllergySeverity { mild, moderate, severe, unknown }

enum VaccinationStatus { administered, historical, not_done, entered_in_error }

enum ConditionStatus { active, inactive, resolved, entered_in_error }

T _enumFromString<T extends Enum>(List<T> values, Object? raw, T fallback) {
  final text = raw?.toString().trim().toLowerCase();
  for (final value in values) {
    if (value.name == text) return value;
  }
  return fallback;
}

String? _clinicalString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

List<T> _clinicalList<T>(Object? raw, T Function(Map<String, Object?>) decode) {
  if (raw is! List) return <T>[];
  return raw
      .whereType<Map>()
      .map(
        (item) =>
            decode(item.map((key, value) => MapEntry(key.toString(), value))),
      )
      .toList(growable: false);
}

@immutable
class ProfileAllergy {
  const ProfileAllergy({
    this.allergyId,
    required this.category,
    required this.substance,
    this.reaction,
    this.severity,
    this.notes,
    this.isActive = true,
  });
  final String? allergyId;
  final AllergyCategory category;
  final String substance;
  final String? reaction;
  final AllergySeverity? severity;
  final String? notes;
  final bool isActive;

  factory ProfileAllergy.fromJson(Map<String, Object?> json) => ProfileAllergy(
    allergyId: _clinicalString(json['allergy_id']),
    category: _enumFromString(
      AllergyCategory.values,
      json['category'],
      AllergyCategory.other,
    ),
    substance: _clinicalString(json['substance']) ?? '',
    reaction: _clinicalString(json['reaction']),
    severity: json['severity'] == null
        ? null
        : _enumFromString(
            AllergySeverity.values,
            json['severity'],
            AllergySeverity.unknown,
          ),
    notes: _clinicalString(json['notes']),
    isActive: json['is_active'] != false,
  );
  Map<String, Object?> toJson() => {
    if (allergyId != null) 'allergy_id': allergyId,
    'category': category.name,
    'substance': substance,
    'reaction': reaction,
    'severity': severity?.name,
    'notes': notes,
    'is_active': isActive,
  };
}

@immutable
class ProfileVaccination {
  const ProfileVaccination({
    this.vaccinationId,
    required this.vaccineName,
    this.status = VaccinationStatus.administered,
    this.administeredOn,
    this.doseNumber,
    this.manufacturer,
    this.batchNumber,
    this.facility,
    this.nextDueOn,
    this.notes,
  });
  final String? vaccinationId;
  final String vaccineName;
  final VaccinationStatus status;
  final String? administeredOn;
  final int? doseNumber;
  final String? manufacturer;
  final String? batchNumber;
  final String? facility;
  final String? nextDueOn;
  final String? notes;

  factory ProfileVaccination.fromJson(Map<String, Object?> json) =>
      ProfileVaccination(
        vaccinationId: _clinicalString(json['vaccination_id']),
        vaccineName: _clinicalString(json['vaccine_name']) ?? '',
        status: _enumFromString(
          VaccinationStatus.values,
          json['status'],
          VaccinationStatus.administered,
        ),
        administeredOn: _clinicalString(json['administered_on']),
        doseNumber: json['dose_number'] is num
            ? (json['dose_number'] as num).toInt()
            : null,
        manufacturer: _clinicalString(json['manufacturer']),
        batchNumber: _clinicalString(json['batch_number']),
        facility: _clinicalString(json['facility']),
        nextDueOn: _clinicalString(json['next_due_on']),
        notes: _clinicalString(json['notes']),
      );
  Map<String, Object?> toJson() => {
    if (vaccinationId != null) 'vaccination_id': vaccinationId,
    'vaccine_name': vaccineName,
    'status': status.name,
    'administered_on': administeredOn,
    'dose_number': doseNumber,
    'manufacturer': manufacturer,
    'batch_number': batchNumber,
    'facility': facility,
    'next_due_on': nextDueOn,
    'notes': notes,
  };
}

@immutable
class ProfileCondition {
  const ProfileCondition({
    this.conditionId,
    required this.name,
    this.status = ConditionStatus.active,
    this.code,
    this.codeSystem,
    this.diagnosedOn,
    this.resolvedOn,
    this.notes,
  });
  final String? conditionId;
  final String name;
  final ConditionStatus status;
  final String? code;
  final String? codeSystem;
  final String? diagnosedOn;
  final String? resolvedOn;
  final String? notes;

  factory ProfileCondition.fromJson(Map<String, Object?> json) =>
      ProfileCondition(
        conditionId: _clinicalString(json['condition_id']),
        name: _clinicalString(json['name']) ?? '',
        status: _enumFromString(
          ConditionStatus.values,
          json['status'],
          ConditionStatus.active,
        ),
        code: _clinicalString(json['code']),
        codeSystem: _clinicalString(json['code_system']),
        diagnosedOn: _clinicalString(json['diagnosed_on']),
        resolvedOn: _clinicalString(json['resolved_on']),
        notes: _clinicalString(json['notes']),
      );
  Map<String, Object?> toJson() => {
    if (conditionId != null) 'condition_id': conditionId,
    'name': name,
    'status': status.name,
    'code': code,
    'code_system': codeSystem,
    'diagnosed_on': diagnosedOn,
    'resolved_on': resolvedOn,
    'notes': notes,
  };
}

@immutable
class ProfileLinkedContact {
  const ProfileLinkedContact({
    required this.accountNumber,
    required this.relationship,
    required this.isActive,
    this.contactDisplayName,
  });

  final String accountNumber;
  final String? contactDisplayName;
  final ProfileContactRelationship relationship;
  final bool isActive;

  static String? _readNullableString(Map<String, Object?> json, String key) {
    final value = json[key];

    if (value == null) return null;

    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return null;
  }

  static String _readRequiredString(Map<String, Object?> json, String key) {
    final value = _readNullableString(json, key);

    if (value == null) {
      throw FormatException('Missing required field: $key');
    }

    return value;
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

  factory ProfileLinkedContact.fromJson(Map<String, Object?> json) {
    return ProfileLinkedContact(
      accountNumber: _readRequiredString(json, 'account_number'),
      contactDisplayName: _readNullableString(json, 'contact_display_name'),
      relationship: ProfileContactRelationship.fromJson(json['relationship']),
      isActive: _readBool(json, 'is_active', fallback: true),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'account_number': accountNumber,
      'contact_display_name': contactDisplayName,
      'relationship': relationship.name,
      'is_active': isActive,
    };
  }

  ProfileLinkedContact copyWith({
    String? accountNumber,
    String? contactDisplayName,
    ProfileContactRelationship? relationship,
    bool? isActive,
  }) {
    return ProfileLinkedContact(
      accountNumber: accountNumber ?? this.accountNumber,
      contactDisplayName: contactDisplayName ?? this.contactDisplayName,
      relationship: relationship ?? this.relationship,
      isActive: isActive ?? this.isActive,
    );
  }
}

enum ProfileRelationship {
  spouse,
  parent,
  child,
  guardian,
  ward,
  sibling,
  other;

  static ProfileRelationship fromJson(Object? value) =>
      ProfileRelationship.values.firstWhere(
        (e) => e.name == value?.toString().trim().toLowerCase(),
        orElse: () => ProfileRelationship.other,
      );
}

@immutable
class RelatedProfile {
  const RelatedProfile({
    required this.profileId,
    required this.fullName,
    required this.relationship,
  });
  final String profileId;
  final String fullName;
  final ProfileRelationship relationship;

  factory RelatedProfile.fromJson(Map<String, Object?> json) => RelatedProfile(
    profileId: json['profile_id']?.toString() ?? '',
    fullName: json['full_name']?.toString() ?? '',
    relationship: ProfileRelationship.fromJson(json['relationship']),
  );
}

@immutable
class Profile {
  const Profile({
    required this.profileId,
    required this.fullName,
    required this.isActive,
    this.dob,
    this.gender,
    this.phone,
    this.email,
    this.nationalId,
    this.notes,
    this.currentMedications,
    this.socialHistory,
    this.familyHistory,
    this.surgicalHistory,
    this.pastMedicalHistory,
    this.allergyStatus = AllergyStatus.unknown,
    this.allergies = const <ProfileAllergy>[],
    this.vaccinations = const <ProfileVaccination>[],
    this.conditions = const <ProfileCondition>[],
    this.linkedContacts = const <ProfileLinkedContact>[],
    this.linkId,
    this.accountNumber,
    this.contactDisplayName,
    this.relationship,
    this.createdAt,
    this.updatedAt,
  });

  final String profileId;
  final String fullName;
  final String? dob;
  final ProfileGender? gender;

  final String? phone;
  final String? email;
  final String? nationalId;
  final String? notes;
  final String? currentMedications;
  final String? socialHistory;
  final String? familyHistory;
  final String? surgicalHistory;
  final String? pastMedicalHistory;
  final AllergyStatus allergyStatus;
  final List<ProfileAllergy> allergies;
  final List<ProfileVaccination> vaccinations;
  final List<ProfileCondition> conditions;

  final bool isActive;

  final List<ProfileLinkedContact> linkedContacts;

  final String? linkId;
  final String? accountNumber;
  final String? contactDisplayName;
  final ProfileContactRelationship? relationship;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  List<ProfileLinkedContact> get activeLinkedContacts {
    return linkedContacts
        .where((contact) => contact.isActive)
        .toList(growable: false);
  }

  ProfileLinkedContact? get primaryLinkedContact {
    if (linkedContacts.isEmpty) return null;

    final activeSelf = linkedContacts.where(
      (contact) =>
          contact.isActive &&
          contact.relationship == ProfileContactRelationship.self,
    );

    if (activeSelf.isNotEmpty) return activeSelf.first;

    final active = activeLinkedContacts;
    if (active.isNotEmpty) return active.first;

    return linkedContacts.first;
  }

  bool get hasLinkedContacts => linkedContacts.isNotEmpty;

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

  factory Profile.fromJson(Map<String, Object?> json) {
    final relationshipRaw = _readNullableString(json, 'relationship');
    final genderRaw = _readNullableString(json, 'gender');

    return Profile(
      profileId: _readRequiredString(json, 'profile_id'),
      fullName: _readRequiredString(json, 'full_name'),
      dob: _readNullableString(json, 'dob'),
      gender: genderRaw == null ? null : ProfileGender.fromJson(genderRaw),
      phone: _readNullableString(json, 'phone'),
      email: _readNullableString(json, 'email'),
      nationalId: _readNullableString(json, 'national_id'),
      notes: _readNullableString(json, 'notes'),
      currentMedications: _readNullableString(json, 'current_medications'),
      socialHistory: _readNullableString(json, 'social_history'),
      familyHistory: _readNullableString(json, 'family_history'),
      surgicalHistory: _readNullableString(json, 'surgical_history'),
      pastMedicalHistory: _readNullableString(json, 'past_medical_history'),
      allergyStatus: _enumFromString(
        AllergyStatus.values,
        json['allergy_status'],
        AllergyStatus.unknown,
      ),
      allergies: _clinicalList(json['allergies'], ProfileAllergy.fromJson),
      vaccinations: _clinicalList(
        json['vaccinations'],
        ProfileVaccination.fromJson,
      ),
      conditions: _clinicalList(json['conditions'], ProfileCondition.fromJson),
      isActive: _readBool(json, 'is_active', fallback: true),
      linkedContacts: const <ProfileLinkedContact>[],
      linkId: _readNullableString(json, 'link_id'),
      accountNumber: _readNullableString(json, 'account_number'),
      contactDisplayName: _readNullableString(json, 'contact_display_name'),
      relationship: relationshipRaw == null
          ? null
          : ProfileContactRelationship.fromJson(relationshipRaw),
      createdAt: _readDateTime(json, 'created_at'),
      updatedAt: _readDateTime(json, 'updated_at'),
    );
  }

  Profile copyWith({
    String? profileId,
    String? fullName,
    String? dob,
    ProfileGender? gender,
    String? phone,
    String? email,
    String? nationalId,
    String? notes,
    String? currentMedications,
    String? socialHistory,
    String? familyHistory,
    String? surgicalHistory,
    String? pastMedicalHistory,
    AllergyStatus? allergyStatus,
    List<ProfileAllergy>? allergies,
    List<ProfileVaccination>? vaccinations,
    List<ProfileCondition>? conditions,
    bool? isActive,
    List<ProfileLinkedContact>? linkedContacts,
    String? linkId,
    String? accountNumber,
    String? contactDisplayName,
    ProfileContactRelationship? relationship,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      profileId: profileId ?? this.profileId,
      fullName: fullName ?? this.fullName,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      nationalId: nationalId ?? this.nationalId,
      notes: notes ?? this.notes,
      currentMedications: currentMedications ?? this.currentMedications,
      socialHistory: socialHistory ?? this.socialHistory,
      familyHistory: familyHistory ?? this.familyHistory,
      surgicalHistory: surgicalHistory ?? this.surgicalHistory,
      pastMedicalHistory: pastMedicalHistory ?? this.pastMedicalHistory,
      allergyStatus: allergyStatus ?? this.allergyStatus,
      allergies: allergies ?? this.allergies,
      vaccinations: vaccinations ?? this.vaccinations,
      conditions: conditions ?? this.conditions,
      isActive: isActive ?? this.isActive,
      linkedContacts: linkedContacts ?? this.linkedContacts,
      linkId: linkId ?? this.linkId,
      accountNumber: accountNumber ?? this.accountNumber,
      contactDisplayName: contactDisplayName ?? this.contactDisplayName,
      relationship: relationship ?? this.relationship,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
class ProfileUpsertInput {
  const ProfileUpsertInput({
    required this.fullName,
    this.dob,
    this.gender = ProfileGender.unknown,
    this.accountNumber,
    this.relationship = ProfileContactRelationship.other,
    this.phone,
    this.email,
    this.nationalId,
    this.notes,
    this.currentMedications,
    this.socialHistory,
    this.familyHistory,
    this.surgicalHistory,
    this.pastMedicalHistory,
    this.allergyStatus,
    this.allergies,
    this.vaccinations,
    this.conditions,
    this.isActive = true,
  });

  final String fullName;
  final String? dob;
  final ProfileGender gender;
  final String? accountNumber;
  final ProfileContactRelationship relationship;
  final String? phone;
  final String? email;
  final String? nationalId;
  final String? notes;
  final String? currentMedications;
  final String? socialHistory;
  final String? familyHistory;
  final String? surgicalHistory;
  final String? pastMedicalHistory;
  final AllergyStatus? allergyStatus;
  final List<ProfileAllergy>? allergies;
  final List<ProfileVaccination>? vaccinations;
  final List<ProfileCondition>? conditions;
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
      'account_number': _nullable(accountNumber),
      'relationship': relationship.name,
      'phone': _nullable(phone),
      'email': _nullable(email),
      'national_id': _nullable(nationalId),
      'notes': _nullable(notes),
      'current_medications': _nullable(currentMedications),
      'social_history': _nullable(socialHistory),
      'family_history': _nullable(familyHistory),
      'surgical_history': _nullable(surgicalHistory),
      'past_medical_history': _nullable(pastMedicalHistory),
      if (allergyStatus != null) 'allergy_status': allergyStatus!.name,
      if (allergies != null)
        'allergies': allergies!.map((e) => e.toJson()).toList(),
      if (vaccinations != null)
        'vaccinations': vaccinations!.map((e) => e.toJson()).toList(),
      if (conditions != null)
        'conditions': conditions!.map((e) => e.toJson()).toList(),
      'is_active': isActive,
    };
  }

  factory ProfileUpsertInput.fromProfile(Profile profile) {
    final linkedContact = profile.primaryLinkedContact;

    return ProfileUpsertInput(
      fullName: profile.fullName,
      dob: profile.dob,
      gender: profile.gender ?? ProfileGender.unknown,
      accountNumber: profile.accountNumber ?? linkedContact?.accountNumber,
      relationship:
          profile.relationship ??
          linkedContact?.relationship ??
          ProfileContactRelationship.other,
      phone: profile.phone,
      email: profile.email,
      nationalId: profile.nationalId,
      notes: profile.notes,
      currentMedications: profile.currentMedications,
      socialHistory: profile.socialHistory,
      familyHistory: profile.familyHistory,
      surgicalHistory: profile.surgicalHistory,
      pastMedicalHistory: profile.pastMedicalHistory,
      // Existing edit forms do not expose these collections; preserve them.
      // Do not send arrays unless the clinical editor intentionally changes them.
      isActive: profile.isActive,
    );
  }
}

@immutable
class ProfileLinkToSelfInput {
  const ProfileLinkToSelfInput({
    this.relationship = ProfileContactRelationship.self,
    this.confirmFullName,
    this.confirmGender,
    this.confirmDob,
    this.confirmPhone,
    this.confirmEmail,
    this.confirmNationalId,
  });

  final ProfileContactRelationship relationship;
  final String? confirmFullName;
  final ProfileGender? confirmGender;
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

@immutable
class ProfileContactLinkInput {
  const ProfileContactLinkInput({
    this.accountNumber,
    this.contactDisplayName,
    this.relationship = ProfileContactRelationship.other,
    this.isActive = true,
  });

  final String? accountNumber;
  final String? contactDisplayName;
  final ProfileContactRelationship relationship;
  final bool isActive;

  Map<String, Object?> toJson() => <String, Object?>{
    'account_number': accountNumber?.trim().toUpperCase(),
    'contact_display_name': contactDisplayName?.trim(),
    'relationship': relationship.name,
    'is_active': isActive,
  };
}
