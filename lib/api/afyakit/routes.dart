// lib/api/afyakit/routes.dart

import 'package:afyakit/api/afyakit/config.dart';
import 'package:afyakit/api/shared/uri.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_type_enum.dart';

class AfyaKitRoutes {
  final String tenantId;
  AfyaKitRoutes(this.tenantId);

  // ─────────────────────────────────────────────
  // Bases
  // ─────────────────────────────────────────────
  String get _tenantBase => apiBaseUrl(tenantId);

  /// Core base (trim the tenant suffix → https://host/api)
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
    final uri = Uri.parse(joinBaseAndPath(_tenantBase, path));
    debugUri('URI tenant', uri);
    return query != null ? uri.replace(queryParameters: query) : uri;
  }

  Uri _uriCore(String path, {Map<String, String>? query}) {
    final uri = Uri.parse(joinBaseAndPath(_coreBase, path));
    debugUri('URI core', uri);
    return query != null ? uri.replace(queryParameters: query) : uri;
  }

  String _seg(String s) => Uri.encodeComponent(s);

  // ─────────────────────────────────────────────
  // 🔐 Public auth (tenant-scoped; no auth header)
  // ─────────────────────────────────────────────

  /// Check membership / client status (used around OTP login flows)
  Uri checkUserStatus() => _uri('auth_login/check-user-status');

  /// Start WhatsApp OTP login (phone-first flow)
  Uri waStart() => _uri('auth_login/wa/start');

  /// Start SMS OTP login (Termii)
  Uri smsStart() => _uri('auth_login/sms/start');

  /// Start Email OTP login (phone identity, email delivery)
  Uri emailStart() => _uri('auth_login/email/start');

  /// Verify OTP and get Firebase custom token (WA / SMS / Email)
  Uri otpVerify() => _uri('auth_login/otp/verify');

  // ─────────────────────────────────────────────
  // 👤 Auth Session (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  /// Fetch the current tenant membership profile
  Uri getCurrentUser() => _uri('auth/session/me');

  /// Refresh Firebase custom claims (for elevated roles; clients are no-op)
  Uri syncClaims() => _uri('auth/session/sync-claims');

  // ─────────────────────────────────────────────
  // 👥 Auth Users (tenant-scoped; authenticated)
  // Used by HQ / admin surfaces, not by client login.
  // ─────────────────────────────────────────────

  Uri getAllUsers() => _uri('auth_users');
  Uri getUserById(String uid) => _uri('auth_users/${_seg(uid)}');
  Uri updateUser(String uid) => _uri('auth_users/${_seg(uid)}');
  Uri deleteUser(String uid) => _uri('auth_users/${_seg(uid)}');

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

  /// HQ: upsert membership for a specific tenant/user (role/active flip)
  Uri hqUpsertUserMembership(String targetTenantId, String uid) =>
      _uriCore('tenants/${_seg(targetTenantId)}/auth_users/${_seg(uid)}');

  /// HQ: remove a user from a specific tenant
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

  Uri createBatch(String storeId) =>
      _uri('stores/${_seg(storeId)}/batches'); // POST

  Uri updateBatch(String storeId, String batchId) =>
      _uri('stores/${_seg(storeId)}/batches/${_seg(batchId)}'); // PATCH

  Uri deleteBatch(String storeId, String batchId) =>
      _uri('stores/${_seg(storeId)}/batches/${_seg(batchId)}'); // DELETE

  // ─────────────────────────────────────────────
  // 📥 Imports (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  Uri importInventory({
    required String type,
    bool dryRun = true,
    bool persist = false,
  }) => _uri(
    'imports/inventory',
    query: {'type': type, 'dryRun': '$dryRun', 'persist': '$persist'},
  );

  Uri importInventoryRaw({
    required String type,
    bool dryRun = true,
    bool persist = false,
  }) => _uri(
    'imports/inventory-raw',
    query: {'type': type, 'dryRun': '$dryRun', 'persist': '$persist'},
  );

  Uri importTemplate(String type) => _uri('imports/templates/$type');

  // ─────────────────────────────────────────────
  // 🏓 Ping (tenant-scoped; public or auth—server decides)
  // ─────────────────────────────────────────────

  Uri ping() => _uri('ping');
}
