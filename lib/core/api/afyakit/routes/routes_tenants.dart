// lib/core/api/afyakit/routes/routes_tenants.dart

part of 'routes.dart';

extension AfyaKitTenantRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 🏢 Tenants (HQ/global; core)
  // ─────────────────────────────────────────────

  Uri listTenants() => _uriCore('tenants');
  Uri createTenant() => _uriCore('tenants');
  Uri getTenant(String slug) => _uriCore('tenants/${_seg(slug)}');
  Uri updateTenant(String slug) => _uriCore('tenants/${_seg(slug)}');
  Uri deleteTenant(String slug) => _uriCore('tenants/${_seg(slug)}');

  Uri setTenantStatus(String slug) => _uriCore('tenants/${_seg(slug)}/status');

  Uri setTenantFlag(String slug, String key) =>
      _uriCore('tenants/${_seg(slug)}/flags/${_seg(key)}');

  Uri setTenantOwner(String slug) => _uriCore('tenants/${_seg(slug)}/owner');
  Uri removeTenantOwner(String slug) => _uriCore('tenants/${_seg(slug)}/owner');
}
