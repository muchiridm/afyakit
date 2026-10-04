// lib/core/api/afyakit/routes/routes_hq.dart

part of 'routes.dart';

extension AfyaKitHqRoutes on AfyaKitRoutes {
  // ═════════════════════════════════════════════
  // Tenants
  // /api/hq/tenants
  // ═════════════════════════════════════════════

  Uri listTenants() => _hqTenants();

  Uri createTenant() => _hqTenants();

  Uri getTenant(String tenantId) => _hqTenant(tenantId);

  Uri updateTenant(String tenantId) => _hqTenant(tenantId);

  Uri deleteTenant(String tenantId) => _hqTenant(tenantId);

  Uri setTenantStatus(String tenantId) =>
      _uriCore('hq/tenants/${_seg(tenantId)}/status');

  Uri setTenantFlag(String tenantId, String key) =>
      _uriCore('hq/tenants/${_seg(tenantId)}/flags/${_seg(key)}');

  Uri setTenantOwner(String tenantId) =>
      _uriCore('hq/tenants/${_seg(tenantId)}/owner');

  Uri removeTenantOwner(String tenantId) =>
      _uriCore('hq/tenants/${_seg(tenantId)}/owner');

  // ═════════════════════════════════════════════
  // Tenant apps
  // /api/hq/tenants/:tenantId/apps
  // ═════════════════════════════════════════════

  Uri listTenantApps(String tenantId) => _hqTenantApps(tenantId);

  Uri createTenantApp(String tenantId) => _hqTenantApps(tenantId);

  Uri getTenantApp(String tenantId, String appId) => _hqApp(tenantId, appId);

  Uri updateTenantApp(String tenantId, String appId) => _hqApp(tenantId, appId);

  Uri deleteTenantApp(String tenantId, String appId) => _hqApp(tenantId, appId);

  // ═════════════════════════════════════════════
  // App domains
  // /api/hq/tenants/:tenantId/apps/:appId/domains
  // ═════════════════════════════════════════════

  Uri listAppDomains(String tenantId, String appId) =>
      _hqAppDomains(tenantId, appId);

  Uri addAppDomain(String tenantId, String appId) =>
      _hqAppDomains(tenantId, appId);

  Uri verifyAppDomain(String tenantId, String appId, String domain) => _uriCore(
    'hq/tenants/${_seg(tenantId)}'
    '/apps/${_seg(appId)}'
    '/domains/${_seg(domain)}/verify',
  );

  Uri makePrimaryAppDomain(String tenantId, String appId, String domain) =>
      _uriCore(
        'hq/tenants/${_seg(tenantId)}'
        '/apps/${_seg(appId)}'
        '/domains/${_seg(domain)}/primary',
      );

  Uri updateAppDomain(String tenantId, String appId, String domain) =>
      _hqAppDomain(tenantId, appId, domain);

  Uri removeAppDomain(String tenantId, String appId, String domain) =>
      _hqAppDomain(tenantId, appId, domain);

  // ═════════════════════════════════════════════
  // App Zoho Books
  //
  // /api/hq/tenants/:tenantId/apps/:appId/zoho
  //
  // One resource URI is shared by:
  // GET
  // PUT
  // PATCH
  // DELETE
  // ═════════════════════════════════════════════

  /// Canonical Zoho Books configuration URI
  /// for one app.
  ///
  /// The HTTP method determines whether the
  /// configuration is read, created, updated
  /// or deleted.
  Uri getTenantAppZoho(String tenantId, String appId) =>
      _hqAppZoho(tenantId, appId);

  // Compatibility aliases.
  //
  // These all intentionally resolve to the
  // same app-owned Zoho resource.

  Uri getAppZoho(String tenantId, String appId) =>
      getTenantAppZoho(tenantId, appId);

  Uri putAppZoho(String tenantId, String appId) =>
      getTenantAppZoho(tenantId, appId);

  Uri updateAppZoho(String tenantId, String appId) =>
      getTenantAppZoho(tenantId, appId);

  Uri deleteAppZoho(String tenantId, String appId) =>
      getTenantAppZoho(tenantId, appId);

  // ═════════════════════════════════════════════
  // Global users
  // /api/hq/users
  // ═════════════════════════════════════════════

  Uri listGlobalUsers({
    String? tenant,
    String? search,
    int limit = 50,
  }) => _uriCore(
    'hq/users',
    query: <String, String>{
      if (tenant != null && tenant.trim().isNotEmpty) 'tenantId': tenant.trim(),

      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),

      'limit': '$limit',
    },
  );

  Uri fetchUserMemberships(String uid) =>
      _uriCore('hq/users/${_seg(uid)}/memberships');

  Uri deleteGlobalUser(String uid) => _uriCore('hq/users/${_seg(uid)}');

  // ═════════════════════════════════════════════
  // Superadmins
  // /api/hq/superadmins
  // ═════════════════════════════════════════════

  Uri listSuperAdmins() => _uriCore('hq/superadmins');

  Uri setSuperAdmin(String uid) => _uriCore('hq/superadmins/${_seg(uid)}');

  // ─────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────

  Uri _hqTenants() => _uriCore('hq/tenants');

  Uri _hqTenant(String tenantId) => _uriCore('hq/tenants/${_seg(tenantId)}');

  Uri _hqTenantApps(String tenantId) =>
      _uriCore('hq/tenants/${_seg(tenantId)}/apps');

  Uri _hqApp(String tenantId, String appId) => _uriCore(
    'hq/tenants/${_seg(tenantId)}'
    '/apps/${_seg(appId)}',
  );

  Uri _hqAppDomains(String tenantId, String appId) => _uriCore(
    'hq/tenants/${_seg(tenantId)}'
    '/apps/${_seg(appId)}'
    '/domains',
  );

  Uri _hqAppDomain(String tenantId, String appId, String domain) => _uriCore(
    'hq/tenants/${_seg(tenantId)}'
    '/apps/${_seg(appId)}'
    '/domains/${_seg(domain)}',
  );

  Uri _hqAppZoho(String tenantId, String appId) => _uriCore(
    'hq/tenants/${_seg(tenantId)}'
    '/apps/${_seg(appId)}'
    '/zoho',
  );
}
