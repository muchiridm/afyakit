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

  /// Base URL builder, defined in your environment (e.g. https://api.host/api/:tenantId).
  String get _tenantBase => apiBaseUrl(tenantId);

  /// Core base (trim the tenant suffix).
  String get _coreBase {
    final u = Uri.parse(_tenantBase);
    final segs = u.pathSegments;
    if (segs.isNotEmpty && segs.last == tenantId) {
      final core = u.replace(pathSegments: segs.take(segs.length - 1));
      return core.toString();
    }
    return _tenantBase; // fallback
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
  // 🔐 Public (tenant-scoped, no auth required)
  // ─────────────────────────────────────────────
  Uri checkUserStatus() => _uri('auth/session/check-user-status');
  Uri sendPasswordResetEmail() => _uri('auth/session/send-password-reset');
  Uri devLogin() => _uri('dev/login');

  // ─────────────────────────────────────────────
  // 👤 Auth Session (tenant-scoped, authenticated)
  // ─────────────────────────────────────────────
  Uri getCurrentUser() => _uri('auth/session/me');
  Uri syncClaims() => _uri('auth/session/sync-claims');

  // ─────────────────────────────────────────────
  // 👥 Auth Users (tenant-scoped)
  // ─────────────────────────────────────────────
  Uri getAllUsers() => _uri('auth_users');
  Uri getUserById(String uid) => _uri('auth_users/${_seg(uid)}');
  Uri updateUser(String uid) =>
      _uri('auth_users/${_seg(uid)}'); // ← single generic
  Uri deleteUser(String uid) => _uri('auth_users/${_seg(uid)}');
  Uri inviteUser() => _uri('auth_users/invite');

  // ─────────────────────────────────────────────
  // 🧑‍💼 HQ / Global (core, superadmin-gated on server)
  // ─────────────────────────────────────────────

  /// GET global directory of users (optional filters)
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
  Uri hqListTenantUsers(
    String targetTenantId, {
    String? search,
    int limit = 50,
  }) => _uriCore(
    'tenants/${Uri.encodeComponent(targetTenantId)}/auth_users',
    query: {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      'limit': '$limit',
    },
  );
  Uri hqInviteUser(String targetTenantId) =>
      _uriCore('tenants/${_seg(targetTenantId)}/auth_users/invite');
  Uri hqDeleteUser(String targetTenantId, String uid) =>
      _uriCore('tenants/${_seg(targetTenantId)}/auth_users/${_seg(uid)}');

  // ─────────────────────────────────────────────
  // 🏢 Tenants (HQ/global; NO :tenantId in path)
  // ─────────────────────────────────────────────

  /// GET all tenants (server decides visibility/authorization)
  Uri listTenants() => _uriCore('tenants'); // GET

  /// POST create tenant
  Uri createTenant() => _uriCore('tenants'); // POST

  /// GET a single tenant by slug
  Uri getTenant(String slug) => _uriCore('tenants/${_seg(slug)}'); // GET

  /// PATCH fields on a tenant
  Uri updateTenant(String slug) => _uriCore('tenants/${_seg(slug)}'); // PATCH

  /// DELETE tenant (supports ?hard=1)
  Uri deleteTenant(String slug) => _uriCore('tenants/${_seg(slug)}'); // DELETE

  /// POST body { status: 'active'|'suspended'|'deleted' }
  Uri setTenantStatus(String slug) => _uriCore('tenants/${_seg(slug)}/status');

  /// PATCH body { value: <any JSON> } to set flags[key]
  Uri setTenantFlag(String slug, String key) =>
      _uriCore('tenants/${_seg(slug)}/flags/${_seg(key)}');

  /// POST body { email?: string, uid?: string } — exactly one required
  /// Transfer tenant ownership (server resolves and updates owner fields).
  Uri setTenantOwner(String slug) => _uriCore('tenants/${_seg(slug)}/owner');
  // ApiRoutes (near setTenantOwner)
  Uri removeTenantOwner(String slug) => _uriCore('tenants/${_seg(slug)}/owner');

  /// Domains (also HQ/global)
  Uri listDomains(String slug) => _uriCore('tenants/${_seg(slug)}/domains');
  Uri addDomain(String slug) => _uriCore('tenants/${_seg(slug)}/domains');
  Uri verifyDomain(String slug, String domain) =>
      _uriCore('tenants/${_seg(slug)}/domains/${_seg(domain)}/verify');
  Uri makePrimaryDomain(String slug, String domain) =>
      _uriCore('tenants/${_seg(slug)}/domains/${_seg(domain)}/primary');
  Uri removeDomain(String slug, String domain) =>
      _uriCore('tenants/${_seg(slug)}/domains/${_seg(domain)}');

  // ─────────────────────────────────────────────
  // 📦 Inventory (tenant-scoped)
  // ─────────────────────────────────────────────

  /// GET list by type (query ?type=…)
  Uri inventory(String itemType) =>
      _uri('inventory', query: {'type': itemType});

  /// POST create (requires body + either ?type or body.itemType)
  Uri createItem() => _uri('inventory');

  /// GET/PUT/PATCH/DELETE by id.
  /// For PUT/PATCH/DELETE include ?type=…; GET does not require type.
  Uri itemById(String id, {String? type}) => _uri(
    'inventory/${_seg(id)}',
    query: type != null ? {'type': type} : null,
  );

  // ─────────────────────────────────────────────
  // ⚙️ Preferences (tenant-scoped)
  // ─────────────────────────────────────────────

  /// Operates on /preferences/:itemType/:field
  Uri preferenceField(String itemType, String field) =>
      _uri('preferences/${_seg(itemType)}/${_seg(field)}');

  // ─────────────────────────────────────────────
  // 📍 Inventory Locations (tenant-scoped)
  // ─────────────────────────────────────────────

  /// GET typed locations: /inventory-locations/:type
  Uri getTypedLocations(InventoryLocationType type) =>
      _uri('inventory-locations/${type.asString}');

  /// POST add location: /inventory-locations/:type  (body: { name })
  Uri addTypedLocation(InventoryLocationType type) =>
      _uri('inventory-locations/${type.asString}');

  /// DELETE a typed location: /inventory-locations/:type/:id
  Uri deleteTypedLocation(InventoryLocationType type, String id) =>
      _uri('inventory-locations/${type.asString}/${_seg(id)}');

  // ─────────────────────────────────────────────
  // 🧪 Batches (tenant-scoped, per store)
  // ─────────────────────────────────────────────

  Uri listBatches(String storeId) => _uri('stores/${_seg(storeId)}/batches');

  Uri createBatch(String storeId) => _uri('stores/${_seg(storeId)}/batches');

  Uri updateBatch(String storeId, String batchId) =>
      _uri('stores/${_seg(storeId)}/batches/${_seg(batchId)}');

  Uri deleteBatch(String storeId, String batchId) =>
      _uri('stores/${_seg(storeId)}/batches/${_seg(batchId)}');

  // ─────────────────────────────────────────────
  // 🏓 Ping (tenant-scoped)
  // ─────────────────────────────────────────────

  Uri ping() => _uri('ping');
}
