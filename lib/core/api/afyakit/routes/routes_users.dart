// lib/core/api/afyakit/routes/routes_users.dart

part of 'routes.dart';

extension AfyaKitUserRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 👥 Auth Users (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  Uri getAllUsers() => _uri('auth_users');
  Uri getUserById(String uid) => _uri('auth_users/${_seg(uid)}');
  Uri updateUser(String uid) => _uri('auth_users/${_seg(uid)}');
  Uri deleteUser(String uid) => _uri('auth_users/${_seg(uid)}');

  // ─────────────────────────────────────────────
  // 🧑‍💼 HQ / Global (core; superadmin-gated on server)
  // ─────────────────────────────────────────────

  Uri listGlobalUsers({
    String? tenant,
    String? search,
    int limit = 50,
  }) => _uriCore(
    'users',
    query: {
      if (tenant != null && tenant.trim().isNotEmpty) 'tenantId': tenant.trim(),
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      'limit': '$limit',
    },
  );

  Uri createGlobalUser() => _uriCore('users');
  Uri updateGlobalUser(String uid) => _uriCore('users/${_seg(uid)}');
  Uri deleteGlobalUser(String uid) => _uriCore('users/${_seg(uid)}');

  Uri fetchUserMemberships(String uid) =>
      _uriCore('users/${_seg(uid)}/memberships');

  Uri listSuperAdmins() => _uriCore('superadmins');
  Uri setSuperAdmin(String uid) => _uriCore('superadmins/${_seg(uid)}');

  Uri hqListTenantUsers(
    String targetTenantId, {
    String? search,
    int limit = 50,
  }) => _uriCore(
    'tenants/${_seg(targetTenantId)}/auth_users',
    query: {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      'limit': '$limit',
    },
  );

  Uri hqUpsertUserMembership(String targetTenantId, String uid) =>
      _uriCore('tenants/${_seg(targetTenantId)}/auth_users/${_seg(uid)}');

  Uri hqDeleteUser(String targetTenantId, String uid) =>
      _uriCore('tenants/${_seg(targetTenantId)}/auth_users/${_seg(uid)}');
}
