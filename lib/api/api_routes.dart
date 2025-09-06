import 'package:afyakit/hq/core/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/api/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_type_enum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiRouteProvider = Provider<ApiRoutes>((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  return ApiRoutes(tenantId);
});

class ApiRoutes {
  final String tenantId;
  ApiRoutes(this.tenantId);

  // ─────────────────────────────────────────────
  // Core helpers
  // ─────────────────────────────────────────────

  /// Base URL builder, defined in your environment (e.g. https://host/api/:tenantId).
  String get _tenantBase => apiBaseUrl(tenantId);

  /// Core base (trim the tenant suffix → https://host/api).
  String get _coreBase {
    final u = Uri.parse(_tenantBase);
    final segs = u.pathSegments;
    if (segs.isNotEmpty && segs.last == tenantId) {
      final core = u.replace(pathSegments: segs.take(segs.length - 1));
      return core.toString();
    }
    return _tenantBase; // fallback (misconfig)
  }

  Uri _uri(String path, {Map<String, String>? query}) {
    final uri = Uri.parse('$_tenantBase/$path');
    if (kDebugMode) debugPrint('🧭 URI tenant  → $uri');
    return query != null ? uri.replace(queryParameters: query) : uri;
  }

  Uri _uriCore(String path, {Map<String, String>? query}) {
    final uri = Uri.parse('$_coreBase/$path');
    if (kDebugMode) debugPrint('🧭 URI core    → $uri');
    return query != null ? uri.replace(queryParameters: query) : uri;
  }

  String _seg(String s) => Uri.encodeComponent(s);

  // ─────────────────────────────────────────────
  // 🔐 Public auth (tenant-scoped; no auth header)
  // ─────────────────────────────────────────────
  Uri checkUserStatus() => _uri('auth_login/check-user-status');
  Uri emailResetLogin() => _uri('auth_login/email/reset');
  Uri waStart() => _uri('auth_login/wa/start');
  Uri waVerify() => _uri('auth_login/wa/verify');

  // ─────────────────────────────────────────────
  // 👤 Auth Session (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────
  Uri getCurrentUser() => _uri('auth/session/me');
  Uri syncClaims() => _uri('auth/session/sync-claims');

  // ─────────────────────────────────────────────
  // 👥 Auth Users (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────
  Uri getAllUsers() => _uri('auth_users');
  Uri getUserById(String uid) => _uri('auth_users/${_seg(uid)}');
  Uri updateUser(String uid) => _uri('auth_users/${_seg(uid)}');
  Uri deleteUser(String uid) => _uri('auth_users/${_seg(uid)}');

  /// Invite user into this tenant (email or WhatsApp) — server enforces role/permission.
  Uri inviteUser() => _uri('auth_users/invite');

  // ─────────────────────────────────────────────
  // 🧑‍💼 HQ / Global (core; superadmin-gated on server)
  // ─────────────────────────────────────────────
  Uri listGlobalUsers({String? tenant, String? search, int limit = 50}) =>
      _uriCore(
        'users',
        query: {
          if (tenant != null && tenant.isNotEmpty) 'tenantId': tenant,
          if (search != null && search.isNotEmpty) 'search': search,
          'limit': '$limit',
        },
      );

  Uri fetchUserMemberships(String uid) =>
      _uriCore('users/${_seg(uid)}/memberships');
  Uri listSuperAdmins() => _uriCore('superadmins');
  Uri setSuperAdmin(String uid) => _uriCore('superadmins/${_seg(uid)}');

  /// HQ: list users in a specific tenant
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

  /// HQ: invite into a specific tenant
  Uri hqInviteUser(String targetTenantId) =>
      _uriCore('tenants/${_seg(targetTenantId)}/auth_users/invite');

  /// HQ: remove from a specific tenant
  Uri hqDeleteUser(String targetTenantId, String uid) =>
      _uriCore('tenants/${_seg(targetTenantId)}/auth_users/${_seg(uid)}');

  // ─────────────────────────────────────────────
  // 🏢 Tenants (HQ/global; NO :tenantId suffix in path)
  // ─────────────────────────────────────────────
  Uri listTenants() => _uriCore('tenants'); // GET
  Uri createTenant() => _uriCore('tenants'); // POST
  Uri getTenant(String slug) => _uriCore('tenants/${_seg(slug)}'); // GET
  Uri updateTenant(String slug) => _uriCore('tenants/${_seg(slug)}'); // PATCH
  Uri deleteTenant(String slug) => _uriCore('tenants/${_seg(slug)}'); // DELETE
  Uri setTenantStatus(String slug) =>
      _uriCore('tenants/${_seg(slug)}/status'); // POST
  Uri setTenantFlag(String slug, String key) =>
      _uriCore('tenants/${_seg(slug)}/flags/${_seg(key)}'); // PATCH
  Uri setTenantOwner(String slug) =>
      _uriCore('tenants/${_seg(slug)}/owner'); // POST
  Uri removeTenantOwner(String slug) =>
      _uriCore('tenants/${_seg(slug)}/owner'); // DELETE
  Uri listDomains(String slug) =>
      _uriCore('tenants/${_seg(slug)}/domains'); // GET
  Uri addDomain(String slug) =>
      _uriCore('tenants/${_seg(slug)}/domains'); // POST
  Uri verifyDomain(String slug, String domain) =>
      _uriCore('tenants/${_seg(slug)}/domains/${_seg(domain)}/verify'); // POST
  Uri makePrimaryDomain(String slug, String domain) =>
      _uriCore('tenants/${_seg(slug)}/domains/${_seg(domain)}/primary'); // POST
  Uri removeDomain(String slug, String domain) =>
      _uriCore('tenants/${_seg(slug)}/domains/${_seg(domain)}'); // DELETE

  // ─────────────────────────────────────────────
  // 📦 Inventory (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────
  Uri inventory(String itemType) =>
      _uri('inventory', query: {'type': itemType});
  Uri createItem() => _uri('inventory');
  Uri itemById(String id, {String? type}) => _uri(
    'inventory/${_seg(id)}',
    query: type != null ? {'type': type} : null,
  );

  // ─────────────────────────────────────────────
  // ⚙️ Preferences (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────
  Uri preferenceField(String itemType, String field) =>
      _uri('preferences/${_seg(itemType)}/${_seg(field)}');

  // ─────────────────────────────────────────────
  // 📍 Inventory Locations (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────
  Uri getTypedLocations(InventoryLocationType type) =>
      _uri('inventory-locations/${type.asString}');
  Uri addTypedLocation(InventoryLocationType type) =>
      _uri('inventory-locations/${type.asString}');
  Uri deleteTypedLocation(InventoryLocationType type, String id) =>
      _uri('inventory-locations/${type.asString}/${_seg(id)}');

  // ─────────────────────────────────────────────
  // 🧪 Batches (tenant-scoped; authenticated, per store)
  // ─────────────────────────────────────────────
  Uri listBatches(String storeId) => _uri('stores/${_seg(storeId)}/batches');
  Uri createBatch(String storeId) => _uri('stores/${_seg(storeId)}/batches');
  Uri updateBatch(String storeId, String batchId) =>
      _uri('stores/${_seg(storeId)}/batches/${_seg(batchId)}');
  Uri deleteBatch(String storeId, String batchId) =>
      _uri('stores/${_seg(storeId)}/batches/${_seg(batchId)}');

  // ─────────────────────────────────────────────
  // 🏓 Ping (tenant-scoped; public or auth—server decides)
  // ─────────────────────────────────────────────
  Uri ping() => _uri('ping');
}
