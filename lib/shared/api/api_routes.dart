// lib/shared/api/api_routes.dart
//
// Single source of truth for frontend → backend paths.
// Reads can go directly to Firestore on the FE if desired,
// but all mutations should use these backend endpoints.
//
// Conventions:
// - Tenant-scoped endpoints live under /api/:tenantId/…
// - HQ (global) endpoints live under /api/* (no tenant segment).
// - Use _uri(...) for tenant scope, _uriCore(...) for HQ/core scope.

import 'package:flutter/foundation.dart';
import 'package:afyakit/shared/api/api_client_base.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_type_enum.dart';

class ApiRoutes {
  final String tenantId;
  ApiRoutes(this.tenantId);

  // ─────────────────────────────────────────────
  // Builders
  // ─────────────────────────────────────────────

  /// Build a tenant-scoped URI under /api/:tenantId/…
  Uri _uri(String path, {Map<String, String>? query}) {
    final base = apiBaseUrl(tenantId); // e.g. https://api.host/api/acme
    final uri = Uri.parse('$base/$path');
    if (kDebugMode) debugPrint('🧭 URI tenant  → $uri');
    return query != null ? uri.replace(queryParameters: query) : uri;
  }

  /// Build a core/HQ URI at /api/* (no tenant segment).
  /// We derive the core base by trimming the "/:tenantId" suffix from apiBaseUrl.
  Uri _uriCore(String path, {Map<String, String>? query}) {
    final baseWithTenant = apiBaseUrl(
      tenantId,
    ); // e.g. https://api.host/api/acme
    final suffix = '/$tenantId';
    final coreBase = baseWithTenant.endsWith(suffix)
        ? baseWithTenant.substring(0, baseWithTenant.length - suffix.length)
        : baseWithTenant;
    final uri = Uri.parse('$coreBase/$path');
    if (kDebugMode) debugPrint('🧭 URI core    → $uri');
    return query != null ? uri.replace(queryParameters: query) : uri;
  }

  // ─────────────────────────────────────────────
  // 🔐 Public (tenant-scoped but no auth required)
  // ─────────────────────────────────────────────

  /// POST { email? | phoneNumber? } → check registration + status
  Uri checkUserStatus() => _uri('auth/session/check-user-status');

  /// POST { email } → send password reset email
  Uri sendPasswordResetEmail() => _uri('auth/session/send-password-reset');

  /// POST dev-only login (only available in non-prod backends)
  Uri devLogin() => _uri('dev/login');

  // ─────────────────────────────────────────────
  // 👤 Auth Session (tenant-scoped, authenticated)
  // ─────────────────────────────────────────────

  /// GET current authenticated user (AuthUser)
  Uri getCurrentUser() => _uri('auth/session/me');

  /// POST → ensure tenant claim + sync role/stores from profile
  Uri syncClaims() => _uri('auth/session/sync-claims');

  // ─────────────────────────────────────────────
  // 👥 Auth Users (tenant-scoped)
  // ─────────────────────────────────────────────

  /// POST invite body { email? phoneNumber? role? forceResend? }
  Uri inviteUser() => _uri('auth_users/invite');

  /// GET all auth users
  Uri getAllUsers() => _uri('auth_users');

  /// GET a single auth user by UID
  Uri getUserById(String uid) => _uri('auth_users/${Uri.encodeComponent(uid)}');

  /// Generic PATCH for small fields (e.g. { status }, { email }, { phoneNumber })
  Uri updateUser(String uid) => _uri('auth_users/${Uri.encodeComponent(uid)}');

  /// PATCH { displayName?, phoneNumber?, avatarUrl? }
  Uri updateAuthUserProfile(String uid) =>
      _uri('auth_users/${Uri.encodeComponent(uid)}/profile');

  /// PATCH { role: 'admin'|'manager'|'staff' }
  Uri updateAuthUserRole(String uid) =>
      _uri('auth_users/${Uri.encodeComponent(uid)}/role');

  /// PATCH { stores: [...] }
  Uri updateAuthUserStores(String uid) =>
      _uri('auth_users/${Uri.encodeComponent(uid)}/stores');

  /// DELETE membership for this tenant
  Uri deleteUser(String uid) => _uri('auth_users/${Uri.encodeComponent(uid)}');

  // ─────────────────────────────────────────────
  // 🧑‍💼 HQ / Global (no tenant segment; superadmin-gated where noted)
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

  /// GET list of a user’s memberships across tenants
  Uri fetchUserMemberships(String uid) =>
      _uriCore('users/${Uri.encodeComponent(uid)}/memberships');

  /// GET superadmins
  Uri listSuperAdmins() => _uriCore('superadmins');

  /// POST { value: bool } set/unset superadmin
  Uri setSuperAdmin(String uid) =>
      _uriCore('superadmins/${Uri.encodeComponent(uid)}');

  /// (Superadmin) Invite a user into ANY tenant
  Uri hqInviteUser(String targetTenantId) => _uriCore(
    'tenants/${Uri.encodeComponent(targetTenantId)}/auth_users/invite',
  );

  /// (Superadmin) Delete a user's membership from ANY tenant
  Uri hqDeleteUser(String targetTenantId, String uid) => _uriCore(
    'tenants/${Uri.encodeComponent(targetTenantId)}/auth_users/${Uri.encodeComponent(uid)}',
  );

  // ─────────────────────────────────────────────
  // 🏢 Tenants CRUD (tenant-scoped paths, superadmin-guarded on server)
  // ─────────────────────────────────────────────

  Uri listTenants() => _uri('tenants'); // GET
  Uri createTenant() => _uri('tenants'); // POST

  Uri getTenant(String slug) =>
      _uri('tenants/${Uri.encodeComponent(slug)}'); // GET

  Uri updateTenant(String slug) =>
      _uri('tenants/${Uri.encodeComponent(slug)}'); // PATCH

  Uri deleteTenant(String slug) =>
      _uri('tenants/${Uri.encodeComponent(slug)}'); // DELETE (supports ?hard=1)

  /// POST body { status: 'active'|'suspended'|'deleted' }
  Uri setTenantStatus(String slug) =>
      _uri('tenants/${Uri.encodeComponent(slug)}/status');

  /// PATCH body { value: <any JSON> } to set flags[key]
  Uri setTenantFlag(String slug, String key) => _uri(
    'tenants/${Uri.encodeComponent(slug)}/flags/${Uri.encodeComponent(key)}',
  );

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
    'inventory/${Uri.encodeComponent(id)}',
    query: type != null ? {'type': type} : null,
  );

  // ─────────────────────────────────────────────
  // ⚙️ Preferences (tenant-scoped)
  // ─────────────────────────────────────────────

  /// Operates on /preferences/:itemType/:field
  Uri preferenceField(String itemType, String field) => _uri(
    'preferences/${Uri.encodeComponent(itemType)}/${Uri.encodeComponent(field)}',
  );

  // ─────────────────────────────────────────────
  // 📍 Inventory Locations (tenant-scoped)
  // ─────────────────────────────────────────────

  /// GET typed locations: /inventory-locations?type=store|dispensary|source
  Uri getTypedLocations(InventoryLocationType type) =>
      _uri('inventory-locations', query: {'type': type.asString});

  /// POST add location (body: { name, type })
  Uri addLocation() => _uri('inventory-locations');

  /// DELETE a typed location: /inventory-locations/:type/:id
  Uri deleteTypedLocation(InventoryLocationType type, String id) =>
      _uri('inventory-locations/${type.asString}/${Uri.encodeComponent(id)}');

  // ─────────────────────────────────────────────
  // 🧪 Batches (tenant-scoped, per store)
  // ─────────────────────────────────────────────

  Uri listBatches(String storeId) =>
      _uri('stores/${Uri.encodeComponent(storeId)}/batches');

  Uri createBatch(String storeId) =>
      _uri('stores/${Uri.encodeComponent(storeId)}/batches');

  Uri updateBatch(String storeId, String batchId) => _uri(
    'stores/${Uri.encodeComponent(storeId)}/batches/${Uri.encodeComponent(batchId)}',
  );

  Uri deleteBatch(String storeId, String batchId) => _uri(
    'stores/${Uri.encodeComponent(storeId)}/batches/${Uri.encodeComponent(batchId)}',
  );

  // ─────────────────────────────────────────────
  // 🏓 Ping (tenant-scoped)
  // ─────────────────────────────────────────────
  Uri ping() => _uri('ping');
}
