// lib/hq/tenants/dtos/tenant_payloads.dart

import 'dart:convert';
import 'package:afyakit/hq/tenants/extensions/tenant_status_x.dart';

/// ─────────────────────────────────────────────────────────────
/// Small helpers (DRY)
/// ─────────────────────────────────────────────────────────────
String? _trimOrNull(String? s) {
  final v = s?.trim();
  return (v == null || v.isEmpty) ? null : v;
}

Map<String, dynamic> _omitNulls(Map<String, dynamic> m) {
  m.removeWhere((_, v) => v == null);
  return m;
}

/// ─────────────────────────────────────────────────────────────
/// Enums & tiny types used across dialogs/services
/// ─────────────────────────────────────────────────────────────
enum DomainAction { add, verify, makePrimary, remove }

class DomainOp {
  final DomainAction action;
  final String domain;
  const DomainOp(this.action, this.domain);
}

/// ─────────────────────────────────────────────────────────────
/// Wire-format requests (match backend controllers)
/// ─────────────────────────────────────────────────────────────

/// Body accepted by POST /tenants
class CreateTenantRequest {
  final String displayName;
  final String? slug; // optional; service may slugify
  final String? primaryColor; // e.g. "#1565C0"
  final String? logoPath;
  final Map<String, dynamic>? flags;

  const CreateTenantRequest({
    required this.displayName,
    this.slug,
    this.primaryColor,
    this.logoPath,
    this.flags,
  });

  Map<String, dynamic> toJson() => _omitNulls({
    'displayName': displayName.trim(),
    'slug': _trimOrNull(slug),
    'primaryColor': _trimOrNull(primaryColor),
    'logoPath': _trimOrNull(logoPath),
    if (flags != null && flags!.isNotEmpty) 'flags': flags,
  });
}

/// PATCH /tenants/:slug
class EditTenantPayload {
  final String? displayName;
  final String? primaryColor;
  final String? logoPath;
  final Map<String, dynamic>? flags; // full replace (server can merge)

  const EditTenantPayload({
    this.displayName,
    this.primaryColor,
    this.logoPath,
    this.flags,
  });

  Map<String, dynamic> toJson() => _omitNulls({
    'displayName': _trimOrNull(displayName),
    'primaryColor': _trimOrNull(primaryColor),
    'logoPath': _trimOrNull(logoPath),
    // allow explicit null to clear flags on server if you want that behavior;
    // otherwise, send only when non-null:
    if (flags != null) 'flags': flags,
  });
}

/// POST /tenants/:slug/owner
/// Exactly one of {email, uid} must be provided.
class TransferOwnerPayload {
  final String? email; // exactly one non-null
  final String? uid;

  // Keep const, but only use a compile-time-friendly assert (null XOR).
  const TransferOwnerPayload._({this.email, this.uid})
    : assert(
        (email == null) != (uid == null),
        'Provide exactly one of email or uid',
      );

  /// Factory that trims & validates at runtime.
  factory TransferOwnerPayload.email(String e) {
    final t = e.trim();
    if (t.isEmpty) {
      throw ArgumentError.value(e, 'email', 'must not be empty');
    }
    return TransferOwnerPayload._(email: t);
    // uid stays null
  }

  /// Factory that trims & validates at runtime.
  factory TransferOwnerPayload.uid(String id) {
    final t = id.trim();
    if (t.isEmpty) {
      throw ArgumentError.value(id, 'uid', 'must not be empty');
    }
    return TransferOwnerPayload._(uid: t);
    // email stays null
  }

  /// Since factories guarantee non-empty values, XOR on null is sufficient.
  bool get isValid => (email == null) != (uid == null);

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (email != null) m['email'] = email; // already trimmed
    if (uid != null) m['uid'] = uid; // already trimmed
    return m;
  }
}

/// POST /tenants/:slug/auth_users/invite (HQ)
class InviteTenantAdminPayload {
  final String email;
  final String role; // 'admin' | 'manager' | 'staff'
  final bool forceResend;

  const InviteTenantAdminPayload({
    required this.email,
    this.role = 'admin',
    this.forceResend = false,
  });

  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'role': role,
    'forceResend': forceResend,
  };
}

/// Optionally grant admin by uid (no email invite)
class GrantTenantAdminPayload {
  final String uid;
  final String role; // 'admin' | 'manager' | 'staff'
  final String? email; // informational
  final String? displayName; // informational

  const GrantTenantAdminPayload({
    required this.uid,
    this.role = 'admin',
    this.email,
    this.displayName,
  });

  Map<String, dynamic> toJson() => _omitNulls({
    'uid': uid,
    'role': role,
    'email': _trimOrNull(email),
    'displayName': _trimOrNull(displayName),
  });
}

/// ─────────────────────────────────────────────────────────────
/// UI payloads (what dialogs return) — convert to wire with helpers
/// ─────────────────────────────────────────────────────────────

/// UI-friendly payload from Create dialog.
/// Convert to wire body via [toRequest].
class CreateTenantPayload {
  final String displayName;
  final String? slug;
  final String primaryColor; // default handled in dialog/controller
  final String? logoPath;
  final Map<String, dynamic> flags;

  /// Follow-ups (not part of POST /tenants):
  /// - POST /tenants/:slug/owner (email or uid)
  /// - invite admins
  final String? ownerUid;
  final String? ownerEmail;
  final List<String> seedAdminUids;

  const CreateTenantPayload({
    required this.displayName,
    required this.primaryColor,
    this.slug,
    this.logoPath,
    this.flags = const {},
    this.ownerUid,
    this.ownerEmail,
    this.seedAdminUids = const <String>[],
  });

  CreateTenantRequest toRequest() => CreateTenantRequest(
    displayName: displayName,
    slug: slug,
    primaryColor: primaryColor,
    logoPath: logoPath,
    flags: flags.isEmpty ? null : flags,
  );
}

/// Payload returned by the "Add Admin" dialog (HQ path).
class AddAdminPayload {
  final String email;
  final String role; // 'admin' | 'manager'
  final bool forceResend;

  const AddAdminPayload({
    required this.email,
    required this.role,
    required this.forceResend,
  });
}

/// Result object from the all-in-one Configure dialog.
/// The controller applies these pieces in order.
class ConfigureTenantResult {
  final EditTenantPayload? edit; // PATCH /tenants/:slug
  final TenantStatus? setStatus; // POST .../status
  final String? transferOwnerTarget; // POST .../owner (email or uid)
  final List<DomainOp> domainOps; // domain mutations to perform

  const ConfigureTenantResult({
    this.edit,
    this.setStatus,
    this.transferOwnerTarget,
    this.domainOps = const <DomainOp>[],
  });

  bool get isNoop =>
      edit == null &&
      setStatus == null &&
      transferOwnerTarget == null &&
      domainOps.isEmpty;

  /// Optional: quick JSON export for debugging
  String debugJson() => jsonEncode({
    'edit': edit?.toJson(),
    'setStatus': setStatus?.value,
    'transferOwnerTarget': transferOwnerTarget,
    'domainOps': [
      for (final op in domainOps)
        {'action': op.action.name, 'domain': op.domain},
    ],
  });
}

/// ─────────────────────────────────────────────────────────────
/// Generic response DTOs
/// ─────────────────────────────────────────────────────────────

class InviteResult {
  final String uid;
  final bool authCreated;
  final bool membershipCreated;

  const InviteResult({
    required this.uid,
    required this.authCreated,
    required this.membershipCreated,
  });

  factory InviteResult.fromJson(Map<String, dynamic> j) => InviteResult(
    uid: (j['uid'] ?? '').toString(),
    authCreated: j['authCreated'] == true,
    membershipCreated: j['membershipCreated'] == true,
  );
}
