// lib/hq/users/all_users/all_user_model.dart

import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:afyakit/shared/utils/utils.dart';

class AllUserMembership {
  final String tenantId;

  /// Legacy tenant-level summary. Not authoritative for app access.
  final String role;
  final bool active;
  final String? email;
  final String? status;

  /// Canonical app memberships.
  /// Example: {"dawapap": "active", "occuwell": "disabled"}
  final Map<String, String> appMembershipsByApp;

  /// Canonical staff roles, scoped to each app.
  /// Example: {"dawapap": ["admin"], "occuwell": []}
  final Map<String, List<String>> staffRolesByApp;

  const AllUserMembership({
    required this.tenantId,
    required this.role,
    required this.active,
    this.email,
    this.status,
    this.appMembershipsByApp = const {},
    this.staffRolesByApp = const {},
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
    );
  }

  /// Whether this user belongs to a particular application.
  bool hasAppMembership(String appId) {
    return appMembershipsByApp.containsKey(appId.trim().toLowerCase());
  }

  /// Whether the membership is active.
  bool hasActiveAppMembership(String appId) {
    return active &&
        appMembershipsByApp[appId.trim().toLowerCase()] == 'active';
  }

  /// Staff roles for one application only.
  List<String> rolesForApp(String appId) {
    return List<String>.unmodifiable(
      staffRolesByApp[appId.trim().toLowerCase()] ?? const <String>[],
    );
  }

  /// Effective application staff roles.
  ///
  /// A disabled tenant account or application membership
  /// never grants staff authority.
  List<String> effectiveRolesForApp(String appId) {
    if (!hasActiveAppMembership(appId)) {
      return const <String>[];
    }

    return rolesForApp(appId);
  }

  /// No app-specific staff role means ordinary member.
  String accessLevelForApp(String appId) {
    if (!hasActiveAppMembership(appId)) {
      return 'none';
    }

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
      (appId, appStatus) =>
          MapEntry(appId, <String, Object?>{'status': appStatus}),
    ),
    'staffRolesByApp': staffRolesByApp,
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

  // Cached, not authoritative:
  final List<String> tenantIds;
  final int tenantCount;

  /// Prefer this for HQ user display.
  /// These should come from the backend joined from tenant auth_users SOT.
  final List<AllUserMembership> memberships;

  /// True if a Firebase Auth user with this uid exists.
  /// False → zombie directory row / candidate for reinvite or deletion.
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

    final count = ids.length;

    final authExistsRaw = j['authExists'];
    final authExists = authExistsRaw is bool ? authExistsRaw : true;

    return AllUser(
      id: id,
      email: _s(j['email']),
      emailLower: _norm(_s(j['emailLower']) ?? _s(j['email']) ?? ''),
      displayName: _s(j['displayName']),
      photoURL: _s(j['photoURL']),
      phoneNumber: _s(j['phoneNumber']),
      createdAt: _dt(j['createdAt']),
      lastLoginAt: _dt(j['lastLoginAt']),
      disabled: _b(j['disabled']) ?? false,
      tenantIds: ids,
      tenantCount: count,
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

// helpers

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
  if (v is List) {
    final out = <String>[];
    for (final e in v) {
      if (e is String && e.trim().isNotEmpty) out.add(e.trim());
    }
    return out;
  }
  return null;
}

List<AllUserMembership> _readMemberships(Object? v) {
  if (v == null) return const <AllUserMembership>[];

  if (v is List) {
    return v
        .whereType<Map>()
        .map((e) => AllUserMembership.fromJson(Map<String, Object?>.from(e)))
        .where((m) => m.tenantId.trim().isNotEmpty)
        .toList();
  }

  // Supports backend shape:
  // {
  //   "dawapap": { "role": "admin", "active": true }
  // }
  if (v is Map) {
    final out = <AllUserMembership>[];

    v.forEach((tenantId, rawValue) {
      if (rawValue is! Map) return;

      final m = Map<String, Object?>.from(rawValue);
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
    final appId = key.toString().trim().toLowerCase();

    if (appId.isEmpty || value is! Map) return;

    final status = _s(value['status'])?.trim().toLowerCase();

    if (status == 'active' || status == 'disabled') {
      result[appId] = status!;
    }
  });

  return result;
}

Map<String, List<String>> _readAppStaffRoles(Object? raw) {
  if (raw is! Map) {
    return const <String, List<String>>{};
  }

  final result = <String, List<String>>{};

  raw.forEach((key, value) {
    final appId = key.toString().trim().toLowerCase();

    if (appId.isEmpty || value is! List) return;

    final roles = value
        .whereType<String>()
        .map((role) => role.trim().toLowerCase())
        .where((role) => role.isNotEmpty)
        .toSet()
        .toList();

    result[appId] = roles;
  });

  return result;
}

String _norm(String s) => s.trim().toLowerCase();
