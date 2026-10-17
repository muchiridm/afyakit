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
  spouse, parent, child, guardian, ward, sibling, other;

  static ProfileRelationship fromJson(Object? value) =>
      ProfileRelationship.values.firstWhere(
        (e) => e.name == value?.toString().trim().toLowerCase(),
        orElse: () => ProfileRelationship.other,
      );
}

@immutable
class RelatedProfile {
  const RelatedProfile({required this.profileId, required this.fullName, required this.relationship});
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

  static List<ProfileLinkedContact> _readLinkedContacts(
    Map<String, Object?> json,
  ) {
    final raw = json['linked_contacts'];

    if (raw is! List) return const <ProfileLinkedContact>[];

    return raw
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .map(ProfileLinkedContact.fromJson)
        .toList(growable: false);
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
