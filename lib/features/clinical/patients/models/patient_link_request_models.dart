import 'package:flutter/foundation.dart';

import 'patient_profile_models.dart';

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

  final PatientContactRelationship relationship;
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
      return int.tryParse(value.trim());
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
      relationship: PatientContactRelationship.fromJson(json['relationship']),
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
    this.relationship = PatientContactRelationship.other,
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

  final PatientContactRelationship relationship;
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
    this.accountNumber,
    this.contactDisplayName,
    this.relationship,
  });

  final String? contactId;
  final String? accountNumber;
  final String? contactDisplayName;
  final PatientContactRelationship? relationship;

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'contact_id': _nullable(contactId),
      'account_number': _nullable(accountNumber),
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
