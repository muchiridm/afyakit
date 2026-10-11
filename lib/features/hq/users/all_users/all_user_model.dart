import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:afyakit/shared/utils/utils.dart';

/// One application's email identity. Never inherited from tenant/global email.
class AppEmailRecord {
  const AppEmailRecord({required this.emailLower, required this.verified});
  final String emailLower;
  final bool verified;

  static AppEmailRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final email =
        (raw['emailLower'] is String
                ? raw['emailLower'] as String
                : raw['email'] is String
                ? raw['email'] as String
                : '')
            .trim()
            .toLowerCase();
    if (email.isEmpty) return null;
    return AppEmailRecord(emailLower: email, verified: raw['verified'] == true);
  }

  JsonObj toJson() => <String, Object?>{
    'emailLower': emailLower,
    'verified': verified,
  };
}

class AllUserMembership {
  final String tenantId;

  /// Legacy tenant summary; not authoritative for app identity or access.
  final String role;
  final bool active;
  final String? email;
  final String? status;
  final Map<String, String> appMembershipsByApp;
  final Map<String, List<String>> staffRolesByApp;
  final Map<String, AppEmailRecord> emailsByApp;

  const AllUserMembership({
    required this.tenantId,
    required this.role,
    required this.active,
    this.email,
    this.status,
    this.appMembershipsByApp = const {},
    this.staffRolesByApp = const {},
    this.emailsByApp = const {},
  });

  factory AllUserMembership.fromJson(JsonObj j) {
    final status = _s(j['status']);
    final activeRaw = j['active'];
    return AllUserMembership(
      tenantId: _s(j['tenantId']) ?? _s(j['tenant']) ?? '',
      role: _s(j['role']) ?? 'client',
      active: activeRaw is bool ? activeRaw : (status ?? 'active') == 'active',
      email: _s(j['email']),
      status: status,
      appMembershipsByApp: _readAppMemberships(j['appMembershipsByApp']),
      staffRolesByApp: _readAppStaffRoles(j['staffRolesByApp']),
      emailsByApp: _readAppEmails(j['emailsByApp']),
    );
  }

  AppEmailRecord? appEmail(String appId) =>
      emailsByApp[appId.trim().toLowerCase()];
  String? emailForApp(String appId) => appEmail(appId)?.emailLower;
  bool isEmailVerifiedForApp(String appId) => appEmail(appId)?.verified == true;

  bool hasAppMembership(String appId) =>
      appMembershipsByApp.containsKey(appId.trim().toLowerCase());
  bool hasActiveAppMembership(String appId) =>
      active && appMembershipsByApp[appId.trim().toLowerCase()] == 'active';
  List<String> rolesForApp(String appId) => List<String>.unmodifiable(
    staffRolesByApp[appId.trim().toLowerCase()] ?? const <String>[],
  );
  List<String> effectiveRolesForApp(String appId) =>
      hasActiveAppMembership(appId) ? rolesForApp(appId) : const <String>[];
  String accessLevelForApp(String appId) {
    if (!hasActiveAppMembership(appId)) return 'none';
    final roles = rolesForApp(appId);
    if (roles.contains('owner')) return 'owner';
    if (roles.contains('admin')) return 'admin';
    if (roles.contains('manager')) return 'manager';
    return roles.isEmpty ? 'member' : roles.first;
  }

  JsonObj toJson() => <String, Object?>{
    'tenantId': tenantId,
    'role': role,
    'active': active,
    if (email != null) 'email': email,
    if (status != null) 'status': status,
    'appMembershipsByApp': appMembershipsByApp.map(
      (id, status) => MapEntry(id, <String, Object?>{'status': status}),
    ),
    'staffRolesByApp': staffRolesByApp,
    'emailsByApp': emailsByApp.map(
      (id, record) => MapEntry(id, record.toJson()),
    ),
  };
}

class AllUser {
  final String id;
  final String? email;
  final String emailLower;
  final String? displayName;
  final String? photoURL;
  final String? phoneNumber;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final bool disabled;
  final List<String> tenantIds;
  final int tenantCount;
  final List<AllUserMembership> memberships;
  final bool authExists;

  const AllUser({
    required this.id,
    required this.emailLower,
    this.email,
    this.displayName,
    this.photoURL,
    this.phoneNumber,
    this.createdAt,
    this.lastLoginAt,
    this.disabled = false,
    this.tenantIds = const [],
    this.tenantCount = 0,
    this.memberships = const [],
    this.authExists = true,
  });

  factory AllUser.fromJson(String id, JsonObj j) {
    final memberships = _readMemberships(j['memberships']);
    final idsFromMemberships =
        memberships
            .map((m) => m.tenantId)
            .where((id) => id.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final ids = idsFromMemberships.isNotEmpty
        ? idsFromMemberships
        : (_readStringList(j['tenantIds']) ?? const <String>[]);
    final authExistsRaw = j['authExists'];
    final authExists = authExistsRaw is bool ? authExistsRaw : true;
    return AllUser(
      id: id,
      email: _s(j['email']),
      emailLower: EmailHelper.normalize(
        _s(j['emailLower']) ?? _s(j['email']) ?? '',
      ),
      displayName: _s(j['displayName']),
      photoURL: _s(j['photoURL']),
      phoneNumber: _s(j['phoneNumber']),
      createdAt: _dt(j['createdAt']),
      lastLoginAt: _dt(j['lastLoginAt']),
      disabled: _b(j['disabled']) ?? false,
      tenantIds: ids,
      tenantCount: ids.length,
      memberships: memberships,
      authExists: authExists,
    );
  }

  JsonObj toJson() => <String, Object?>{
    'email': email,
    'emailLower': emailLower.isEmpty ? (email ?? '').toLowerCase() : emailLower,
    'displayName': displayName,
    'photoURL': photoURL,
    'phoneNumber': phoneNumber,
    'createdAt': createdAt,
    'lastLoginAt': lastLoginAt,
    'disabled': disabled,
    'tenantIds': tenantIds,
    'tenantCount': tenantCount,
    'memberships': memberships.map((m) => m.toJson()).toList(),
    'authExists': authExists,
  };
}

String? _s(Object? v) => v is String ? v : null;
bool? _b(Object? v) => v is bool ? v : null;
DateTime? _dt(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v);
  return null;
}

List<String>? _readStringList(Object? v) {
  if (v is! List) return null;
  return v
      .whereType<String>()
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

List<AllUserMembership> _readMemberships(Object? v) {
  if (v is List) {
    return v
        .whereType<Map>()
        .map((e) => AllUserMembership.fromJson(Map<String, Object?>.from(e)))
        .where((m) => m.tenantId.trim().isNotEmpty)
        .toList();
  }
  if (v is Map) {
    final out = <AllUserMembership>[];
    v.forEach((tenantId, raw) {
      if (raw is! Map) return;
      final m = Map<String, Object?>.from(raw);
      m['tenantId'] = tenantId.toString();
      final membership = AllUserMembership.fromJson(m);
      if (membership.tenantId.trim().isNotEmpty) out.add(membership);
    });
    return out;
  }
  return const <AllUserMembership>[];
}

Map<String, String> _readAppMemberships(Object? raw) {
  if (raw is! Map) return const <String, String>{};
  final result = <String, String>{};
  raw.forEach((key, value) {
    final id = key.toString().trim().toLowerCase();
    if (id.isEmpty || value is! Map) return;
    final status = _s(value['status'])?.trim().toLowerCase();
    if (status == 'active' || status == 'disabled') result[id] = status!;
  });
  return result;
}

Map<String, List<String>> _readAppStaffRoles(Object? raw) {
  if (raw is! Map) return const <String, List<String>>{};
  final result = <String, List<String>>{};
  raw.forEach((key, value) {
    final id = key.toString().trim().toLowerCase();
    if (id.isEmpty || value is! List) return;
    result[id] = value
        .whereType<String>()
        .map((r) => r.trim().toLowerCase())
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList();
  });
  return result;
}

Map<String, AppEmailRecord> _readAppEmails(Object? raw) {
  if (raw is! Map) return const <String, AppEmailRecord>{};
  final result = <String, AppEmailRecord>{};
  raw.forEach((key, value) {
    final id = key.toString().trim().toLowerCase();
    if (id.isEmpty) return;
    final record = AppEmailRecord.fromJson(value);
    if (record != null) result[id] = record;
  });
  return result;
}
