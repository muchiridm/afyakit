// lib/hq/tenants/models/tenant_payloads.dart
class CreateTenantPayload {
  final String displayName;
  final String? slug;
  final String primaryColor;
  final String? logoPath;
  final Map<String, dynamic> flags;
  final String? ownerUid;
  final String? ownerEmail;
  final List<String> seedAdminUids;

  CreateTenantPayload({
    required this.displayName,
    required this.primaryColor,
    this.slug,
    this.logoPath,
    this.flags = const {},
    this.ownerUid,
    this.ownerEmail,
    this.seedAdminUids = const <String>[],
  });
}

class EditTenantPayload {
  final String? displayName;
  final String? primaryColor;
  final String? logoPath;
  EditTenantPayload({this.displayName, this.primaryColor, this.logoPath});
}

class AddAdminPayload {
  final String uid;
  final String role; // 'admin' | 'manager'
  final String? email;
  final String? displayName;

  AddAdminPayload({
    required this.uid,
    this.role = 'admin',
    this.email,
    this.displayName,
  });
}

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

class TenantAdminUser {
  final String uid;
  final String email; // may be empty
  final String displayName; // may be empty
  final String role; // 'admin' | 'manager'
  final bool active;

  const TenantAdminUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.active,
  });

  factory TenantAdminUser.fromJson(Map<String, dynamic> j) => TenantAdminUser(
    uid: (j['uid'] ?? '').toString(),
    email: (j['email'] ?? '').toString(),
    displayName: (j['displayName'] ?? '').toString(),
    role: (j['role'] ?? 'admin').toString(),
    active: j['active'] == true,
  );
}

class TenantSummary {
  final String slug;
  final String displayName;
  final String primaryColor;
  final String? logoPath;
  final String status; // 'active' | 'suspended' | etc.
  final String? ownerUid;
  final String? ownerEmail;

  const TenantSummary({
    required this.slug,
    required this.displayName,
    required this.primaryColor,
    this.logoPath,
    required this.status,
    this.ownerUid,
    this.ownerEmail,
  });

  factory TenantSummary.fromJson(Map<String, dynamic> j) => TenantSummary(
    slug: (j['slug'] ?? '').toString(),
    displayName: (j['displayName'] ?? '').toString(),
    primaryColor: (j['primaryColor'] ?? '#1565C0').toString(),
    logoPath: (j['logoPath'] as String?)?.trim().isEmpty == true
        ? null
        : (j['logoPath'] as String?),
    status: (j['status'] ?? 'active').toString(),
    ownerUid: (j['ownerUid'] as String?)?.trim().isEmpty == true
        ? null
        : (j['ownerUid'] as String?),
    ownerEmail: (j['ownerEmail'] as String?)?.trim().isEmpty == true
        ? null
        : (j['ownerEmail'] as String?),
  );
}
