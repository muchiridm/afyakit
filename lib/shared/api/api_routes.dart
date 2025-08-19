// lib/shared/api/api_routes.dart

import 'package:afyakit/features/inventory_locations/inventory_location_type_enum.dart';
import 'package:afyakit/shared/api/api_client_base.dart';
import 'package:flutter/foundation.dart';

class ApiRoutes {
  final String tenantId;
  ApiRoutes(this.tenantId);

  Uri _uri(String path, {Map<String, String>? query}) {
    final base = apiBaseUrl(tenantId);
    final uri = Uri.parse('$base/$path');
    if (kDebugMode) {
      debugPrint('🧭 Building URI → base: $base | path: $path → $uri');
    }
    return query != null ? uri.replace(queryParameters: query) : uri;
  }

  // Strip trailing "/:tenantId" to hit core-level endpoints.
  Uri _uriCore(String path, {Map<String, String>? query}) {
    final baseWithTenant = apiBaseUrl(
      tenantId,
    ); // e.g. https://api.host/api/acme
    final suffix = '/$tenantId';
    final coreBase = baseWithTenant.endsWith(suffix)
        ? baseWithTenant.substring(0, baseWithTenant.length - suffix.length)
        : baseWithTenant;
    final uri = Uri.parse('$coreBase/$path');
    return query != null ? uri.replace(queryParameters: query) : uri;
  }

  // ─────────────────────────────────────────────
  // 🏢 Tenants (management APIs) – CRUD only
  // ─────────────────────────────────────────────
  Uri listTenants() => _uri('tenants'); // GET
  Uri createTenant() => _uri('tenants'); // POST
  Uri getTenant(String slug) =>
      _uri('tenants/${Uri.encodeComponent(slug)}'); // GET
  Uri updateTenant(String slug) =>
      _uri('tenants/${Uri.encodeComponent(slug)}'); // PATCH
  Uri deleteTenant(String slug) =>
      _uri('tenants/${Uri.encodeComponent(slug)}'); // DELETE

  // Compatibility endpoints still used by the UI:
  Uri setTenantStatus(String slug) =>
      _uri('tenants/${Uri.encodeComponent(slug)}/status'); // POST {status}
  Uri setTenantFlag(String slug, String key) => _uri(
    'tenants/${Uri.encodeComponent(slug)}/flags/${Uri.encodeComponent(key)}',
  ); // PATCH {value}

  // ─────────────────────────────────────────────
  // 👥 User Manager (tenant-scoped under /api/:tenantId)
  // ─────────────────────────────────────────────
  Uri inviteUser() => _uri('auth_users/invite'); // POST
  Uri getAllUsers() => _uri('auth_users'); // GET
  Uri getUserById(String uid) =>
      _uri('auth_users/${Uri.encodeComponent(uid)}'); // GET
  Uri updateAuthUserRole(String uid) =>
      _uri('auth_users/${Uri.encodeComponent(uid)}/role'); // PATCH
  Uri updateAuthUserStores(String uid) =>
      _uri('auth_users/${Uri.encodeComponent(uid)}/stores'); // PATCH
  Uri updateUser(String uid) =>
      _uri('auth_users/${Uri.encodeComponent(uid)}'); // PATCH
  Uri updateAuthUserProfile(String uid) =>
      _uri('auth_users/${Uri.encodeComponent(uid)}/profile'); // PATCH
  Uri deleteUser(String uid) =>
      _uri('auth_users/${Uri.encodeComponent(uid)}'); // DELETE

  // ─────────────────────────────────────────────
  // 🌍 Global users directory (core-level, not tenant-scoped)
  // ─────────────────────────────────────────────
  Uri fetchGlobalUsers({String? tenantId, String? search, int limit = 50}) =>
      _uriCore(
        'users',
        query: {
          if (tenantId != null && tenantId.isNotEmpty) 'tenantId': tenantId,
          if (search != null && search.isNotEmpty) 'search': search,
          'limit': '$limit',
        },
      );

  Uri fetchUserMemberships(String uid) =>
      _uriCore('users/${Uri.encodeComponent(uid)}/memberships'); // GET

  // ─────────────────────────────────────────────
  // ⭐ Superadmins (core-level)
  // ─────────────────────────────────────────────
  Uri listSuperAdmins() => _uriCore('superadmins'); // GET
  Uri setSuperAdmin(String uid) =>
      _uriCore('superadmins/${Uri.encodeComponent(uid)}'); // POST {value: bool}

  // ─────────────────────────────────────────────
  // 🔐 Auth (Session + Dev)
  // ─────────────────────────────────────────────
  Uri login() => _uri('auth/login');
  Uri syncClaims() => _uri('auth/session/sync-claims');
  Uri getCurrentUser() => _uri('auth/session/me');
  Uri checkUserStatus() => _uri('auth/session/check-user-status');
  Uri sendPasswordResetEmail() => _uri('auth/session/send-password-reset');

  // ─────────────────────────────────────────────
  // 📦 Inventory
  // ─────────────────────────────────────────────
  Uri inventory(String itemType) =>
      _uri('inventory', query: {'type': itemType});
  Uri createItem() => _uri('inventory');
  Uri itemById(String id, [String? itemType]) => _uri(
    'inventory/${Uri.encodeComponent(id)}',
    query: itemType != null ? {'type': itemType} : null,
  );

  // ─────────────────────────────────────────────
  // ⚙️ Preferences
  // ─────────────────────────────────────────────
  Uri preferenceField(String type, String field) => _uri(
    'preferences/${Uri.encodeComponent(type)}/${Uri.encodeComponent(field)}',
  );

  // ─────────────────────────────────────────────
  // 📍 Typed Inventory Location Routes
  // ─────────────────────────────────────────────
  Uri getTypedLocationsUri(InventoryLocationType type) =>
      _uri('inventory-locations', query: {'type': type.asString});
  Uri addTypedLocationWithIdUri(InventoryLocationType type, String id) =>
      _uri('inventory-locations/${type.asString}/${Uri.encodeComponent(id)}');
  Uri deleteTypedLocationUri(InventoryLocationType type, String id) =>
      _uri('inventory-locations/${type.asString}/${Uri.encodeComponent(id)}');
  Uri addLocationUri() => _uri('inventory-locations');

  // ─────────────────────────────────────────────
  // 🧪 Batches
  // ─────────────────────────────────────────────
  Uri createBatchUri(String storeId) =>
      _uri('stores/${Uri.encodeComponent(storeId)}/batches');
  Uri updateBatchUri(String storeId, String batchId) => _uri(
    'stores/${Uri.encodeComponent(storeId)}/batches/${Uri.encodeComponent(batchId)}',
  );
  Uri deleteBatchUri(String storeId, String batchId) => _uri(
    'stores/${Uri.encodeComponent(storeId)}/batches/${Uri.encodeComponent(batchId)}',
  );
}
