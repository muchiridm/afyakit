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

  /// GET /api/users?tenantId=&search=&limit=
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

  /// GET /api/users/:uid/memberships
  Uri fetchUserMemberships(String uid) =>
      _uriCore('users/${_seg(uid)}/memberships');

  // Superadmins (global)
  Uri listSuperAdmins() => _uriCore('superadmins');
  Uri setSuperAdmin(String uid) => _uriCore('superadmins/${_seg(uid)}');

  // ─────────────────────────────────────────────
  // 🧑‍💼 HQ / Tenant user management (tenant auth_users)
  // ─────────────────────────────────────────────

  /// GET /api/tenants/:tenantId/auth_users
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

  /// ✅ POST /api/tenants/:tenantId/auth_users
  /// body: { phoneNumber, displayName? }
  Uri hqCreateTenantUser(String targetTenantId) =>
      _uriCore('tenants/${_seg(targetTenantId)}/auth_users');

  /// GET /api/tenants/:tenantId/auth_users/:uid
  Uri hqGetTenantUserById(String targetTenantId, String uid) =>
      _uriCore('tenants/${_seg(targetTenantId)}/auth_users/${_seg(uid)}');

  /// PATCH /api/tenants/:tenantId/auth_users/:uid
  Uri hqPatchTenantUser(String targetTenantId, String uid) =>
      _uriCore('tenants/${_seg(targetTenantId)}/auth_users/${_seg(uid)}');

  /// DELETE /api/tenants/:tenantId/auth_users/:uid
  Uri hqDeleteTenantUser(String targetTenantId, String uid) =>
      _uriCore('tenants/${_seg(targetTenantId)}/auth_users/${_seg(uid)}');
}
