// lib/core/api/afyakit/routes/routes_tenants.dart

part of 'routes.dart';

extension AfyaKitTenantRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 🏢 Tenants (HQ/global; core)
  // ─────────────────────────────────────────────

  Uri listTenants() => _uriCore('tenants');
  Uri createTenant() => _uriCore('tenants');
  Uri getTenant(String tenantId) => _uriCore('tenants/${_seg(tenantId)}');
  Uri updateTenant(String tenantId) => _uriCore('tenants/${_seg(tenantId)}');
  Uri deleteTenant(String tenantId) => _uriCore('tenants/${_seg(tenantId)}');

  Uri setTenantStatus(String tenantId) =>
      _uriCore('tenants/${_seg(tenantId)}/status');

  Uri setTenantFlag(String tenantId, String key) =>
      _uriCore('tenants/${_seg(tenantId)}/flags/${_seg(key)}');

  Uri setTenantOwner(String tenantId) =>
      _uriCore('tenants/${_seg(tenantId)}/owner');
  Uri removeTenantOwner(String tenantId) =>
      _uriCore('tenants/${_seg(tenantId)}/owner');
}
