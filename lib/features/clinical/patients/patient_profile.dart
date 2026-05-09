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

enum PatientLinkApprovalMode {
  owner,
  staff;

  static PatientLinkApprovalMode fromJson(Object? value) {
    final raw = value?.toString().trim().toLowerCase();

    return PatientLinkApprovalMode.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => PatientLinkApprovalMode.staff,
    );
  }
}

enum PatientLinkRequestStatus {
  pendingOwnerApproval,
  pendingStaffApproval,
  approved,
  rejected,
  cancelled;

  String get wire {
    switch (this) {
      case PatientLinkRequestStatus.pendingOwnerApproval:
        return 'pending_owner_approval';
      case PatientLinkRequestStatus.pendingStaffApproval:
        return 'pending_staff_approval';
      case PatientLinkRequestStatus.approved:
        return 'approved';
      case PatientLinkRequestStatus.rejected:
        return 'rejected';
      case PatientLinkRequestStatus.cancelled:
        return 'cancelled';
    }
  }

  static PatientLinkRequestStatus fromJson(Object? value) {
    final raw = value?.toString().trim().toLowerCase();

    switch (raw) {
      case 'pending_owner_approval':
      case 'pendingownerapproval':
        return PatientLinkRequestStatus.pendingOwnerApproval;
      case 'pending_staff_approval':
      case 'pendingstaffapproval':
        return PatientLinkRequestStatus.pendingStaffApproval;
      case 'approved':
        return PatientLinkRequestStatus.approved;
      case 'rejected':
        return PatientLinkRequestStatus.rejected;
      case 'cancelled':
      case 'canceled':
        return PatientLinkRequestStatus.cancelled;
      default:
        return PatientLinkRequestStatus.pendingStaffApproval;
    }
  }
}

enum PatientLinkApprovedByRole {
  ownerContact,
  staff;

  static PatientLinkApprovedByRole? fromJson(Object? value) {
    final raw = value?.toString().trim().toLowerCase();

    switch (raw) {
      case 'owner_contact':
      case 'ownercontact':
        return PatientLinkApprovedByRole.ownerContact;
      case 'staff':
        return PatientLinkApprovedByRole.staff;
      default:
        return null;
    }
  }
}

@immutable
class PatientLinkedContact {
  const PatientLinkedContact({
    required this.contactId,
    required this.relationship,
    required this.isActive,
    this.contactDisplayName,
  });

  final String contactId;
  final String? contactDisplayName;
  final ContactPatientRelationship relationship;
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

  factory PatientLinkedContact.fromJson(Map<String, Object?> json) {
    return PatientLinkedContact(
      contactId: _readRequiredString(json, 'contact_id'),
      contactDisplayName: _readNullableString(json, 'contact_display_name'),
      relationship: ContactPatientRelationship.fromJson(json['relationship']),
      isActive: _readBool(json, 'is_active', fallback: true),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'contact_id': contactId,
      'contact_display_name': contactDisplayName,
      'relationship': relationship.name,
      'is_active': isActive,
    };
  }

  PatientLinkedContact copyWith({
    String? contactId,
    String? contactDisplayName,
    ContactPatientRelationship? relationship,
    bool? isActive,
  }) {
    return PatientLinkedContact(
      contactId: contactId ?? this.contactId,
      contactDisplayName: contactDisplayName ?? this.contactDisplayName,
      relationship: relationship ?? this.relationship,
      isActive: isActive ?? this.isActive,
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
    this.linkedContacts = const <PatientLinkedContact>[],
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

  /// Persistent denormalized contact associations returned by the BE.
  ///
  /// This is useful for staff views where one patient may be linked to
  /// multiple payers, guardians, employers, insurers, or family contacts.
  final List<PatientLinkedContact> linkedContacts;

  /// Contextual link fields returned when the patient is viewed through
  /// one specific contact association.
  ///
  /// Keep these separate from [linkedContacts]. They answer:
  /// “Which contact relationship produced this current row?”
  final String? linkId;
  final String? contactId;
  final String? contactDisplayName;
  final ContactPatientRelationship? relationship;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  List<PatientLinkedContact> get activeLinkedContacts {
    return linkedContacts
        .where((contact) => contact.isActive)
        .toList(growable: false);
  }

  PatientLinkedContact? get primaryLinkedContact {
    if (linkedContacts.isEmpty) return null;

    final activeSelf = linkedContacts.where(
      (contact) =>
          contact.isActive &&
          contact.relationship == ContactPatientRelationship.self,
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

  static List<PatientLinkedContact> _readLinkedContacts(
    Map<String, Object?> json,
  ) {
    final raw = json['linked_contacts'];

    if (raw is! List) return const <PatientLinkedContact>[];

    return raw
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .map(PatientLinkedContact.fromJson)
        .toList(growable: false);
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
      linkedContacts: _readLinkedContacts(json),
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
    List<PatientLinkedContact>? linkedContacts,
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
      linkedContacts: linkedContacts ?? this.linkedContacts,
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
    final linkedContact = profile.primaryLinkedContact;

    return PatientProfileUpsertInput(
      fullName: profile.fullName,
      dob: profile.dob,
      gender: profile.gender ?? PatientGender.unknown,
      contactId: profile.contactId ?? linkedContact?.contactId,
      relationship:
          profile.relationship ??
          linkedContact?.relationship ??
          ContactPatientRelationship.self,
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

@immutable
class PatientLinkRequest {
  const PatientLinkRequest({
    required this.requestId,
    required this.patientId,
    required this.patientDisplayName,
    required this.requestedByUid,
    required this.relationship,
    required this.approvalMode,
    required this.status,
    this.requestedByContactId,
    this.requestedByAccountNumber,
    this.requestedByDisplayName,
    this.targetContactId,
    this.targetAccountNumber,
    this.targetContactDisplayName,
    this.targetPhone,
    this.targetEmail,
    this.reason,
    this.confirmFullName,
    this.confirmGender,
    this.confirmDob,
    this.confirmPhone,
    this.confirmEmail,
    this.confirmNationalId,
    this.matchesCount,
    this.approvedByUid,
    this.approvedByContactId,
    this.approvedByRole,
    this.approvedAt,
    this.rejectedByUid,
    this.rejectedReason,
    this.rejectedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String requestId;

  final String patientId;
  final String patientDisplayName;

  final String requestedByUid;
  final String? requestedByContactId;
  final String? requestedByAccountNumber;
  final String? requestedByDisplayName;

  final String? targetContactId;
  final String? targetAccountNumber;
  final String? targetContactDisplayName;
  final String? targetPhone;
  final String? targetEmail;

  final ContactPatientRelationship relationship;
  final String? reason;

  final PatientLinkApprovalMode approvalMode;
  final PatientLinkRequestStatus status;

  final String? confirmFullName;
  final PatientGender? confirmGender;
  final String? confirmDob;
  final String? confirmPhone;
  final String? confirmEmail;
  final String? confirmNationalId;

  final int? matchesCount;

  final String? approvedByUid;
  final String? approvedByContactId;
  final PatientLinkApprovedByRole? approvedByRole;
  final DateTime? approvedAt;

  final String? rejectedByUid;
  final String? rejectedReason;
  final DateTime? rejectedAt;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending {
    return status == PatientLinkRequestStatus.pendingOwnerApproval ||
        status == PatientLinkRequestStatus.pendingStaffApproval;
  }

  bool get needsStaffApproval {
    return status == PatientLinkRequestStatus.pendingStaffApproval ||
        approvalMode == PatientLinkApprovalMode.staff;
  }

  bool get needsOwnerApproval {
    return status == PatientLinkRequestStatus.pendingOwnerApproval ||
        approvalMode == PatientLinkApprovalMode.owner;
  }

  String get bestTargetLabel {
    final display = targetContactDisplayName?.trim();
    if (display != null && display.isNotEmpty) return display;

    final account = targetAccountNumber?.trim();
    if (account != null && account.isNotEmpty) return account;

    final phone = targetPhone?.trim();
    if (phone != null && phone.isNotEmpty) return phone;

    final email = targetEmail?.trim();
    if (email != null && email.isNotEmpty) return email;

    final contactId = targetContactId?.trim();
    if (contactId != null && contactId.isNotEmpty) return contactId;

    return 'Unspecified payer/contact';
  }

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

  static int? _readInt(Map<String, Object?> json, String key) {
    final value = json[key];

    if (value is int) return value;

    if (value is num) return value.toInt();

    if (value is String) {
      final parsed = int.tryParse(value.trim());
      return parsed;
    }

    return null;
  }

  static DateTime? _readDateTime(Map<String, Object?> json, String key) {
    final raw = _readNullableString(json, key);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  factory PatientLinkRequest.fromJson(Map<String, Object?> json) {
    final confirmGenderRaw = _readNullableString(json, 'confirm_gender');
    final approvedByRoleRaw = _readNullableString(json, 'approved_by_role');

    return PatientLinkRequest(
      requestId: _readRequiredString(json, 'request_id'),
      patientId: _readRequiredString(json, 'patient_id'),
      patientDisplayName: _readRequiredString(json, 'patient_display_name'),
      requestedByUid: _readRequiredString(json, 'requested_by_uid'),
      requestedByContactId: _readNullableString(
        json,
        'requested_by_contact_id',
      ),
      requestedByAccountNumber: _readNullableString(
        json,
        'requested_by_account_number',
      ),
      requestedByDisplayName: _readNullableString(
        json,
        'requested_by_display_name',
      ),
      targetContactId: _readNullableString(json, 'target_contact_id'),
      targetAccountNumber: _readNullableString(json, 'target_account_number'),
      targetContactDisplayName: _readNullableString(
        json,
        'target_contact_display_name',
      ),
      targetPhone: _readNullableString(json, 'target_phone'),
      targetEmail: _readNullableString(json, 'target_email'),
      relationship: ContactPatientRelationship.fromJson(json['relationship']),
      reason: _readNullableString(json, 'reason'),
      approvalMode: PatientLinkApprovalMode.fromJson(json['approval_mode']),
      status: PatientLinkRequestStatus.fromJson(json['status']),
      confirmFullName: _readNullableString(json, 'confirm_full_name'),
      confirmGender: confirmGenderRaw == null
          ? null
          : PatientGender.fromJson(confirmGenderRaw),
      confirmDob: _readNullableString(json, 'confirm_dob'),
      confirmPhone: _readNullableString(json, 'confirm_phone'),
      confirmEmail: _readNullableString(json, 'confirm_email'),
      confirmNationalId: _readNullableString(json, 'confirm_national_id'),
      matchesCount: _readInt(json, 'matches_count'),
      approvedByUid: _readNullableString(json, 'approved_by_uid'),
      approvedByContactId: _readNullableString(json, 'approved_by_contact_id'),
      approvedByRole: PatientLinkApprovedByRole.fromJson(approvedByRoleRaw),
      approvedAt: _readDateTime(json, 'approved_at'),
      rejectedByUid: _readNullableString(json, 'rejected_by_uid'),
      rejectedReason: _readNullableString(json, 'rejected_reason'),
      rejectedAt: _readDateTime(json, 'rejected_at'),
      createdAt: _readDateTime(json, 'created_at'),
      updatedAt: _readDateTime(json, 'updated_at'),
    );
  }
}

@immutable
class PatientLinkRequestCreateInput {
  const PatientLinkRequestCreateInput({
    this.relationship = ContactPatientRelationship.other,
    this.targetContactId,
    this.targetAccountNumber,
    this.targetContactDisplayName,
    this.targetPhone,
    this.targetEmail,
    this.reason,
    this.confirmFullName,
    this.confirmGender,
    this.confirmDob,
    this.confirmPhone,
    this.confirmEmail,
    this.confirmNationalId,
  });

  final ContactPatientRelationship relationship;

  /// Staff may pass this directly.
  /// Member requests should generally describe the target using name/account/phone/email.
  final String? targetContactId;

  final String? targetAccountNumber;
  final String? targetContactDisplayName;
  final String? targetPhone;
  final String? targetEmail;
  final String? reason;

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
      'target_contact_id': _nullable(targetContactId),
      'target_account_number': _nullable(targetAccountNumber),
      'target_contact_display_name': _nullable(targetContactDisplayName),
      'target_phone': _nullable(targetPhone),
      'target_email': _nullable(targetEmail),
      'reason': _nullable(reason),
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
class PatientLinkRequestApproveInput {
  const PatientLinkRequestApproveInput({
    this.contactId,
    this.contactDisplayName,
    this.relationship,
  });

  final String? contactId;
  final String? contactDisplayName;
  final ContactPatientRelationship? relationship;

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'contact_id': _nullable(contactId),
      'contact_display_name': _nullable(contactDisplayName),
      'relationship': relationship?.name,
    };
  }
}

@immutable
class PatientLinkRequestRejectInput {
  const PatientLinkRequestRejectInput({this.reason});

  final String? reason;

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{'reason': _nullable(reason)};
  }
}
