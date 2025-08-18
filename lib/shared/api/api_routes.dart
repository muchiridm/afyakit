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

  // ─────────────────────────────────────────────
  // HQ (global) – superadmins & global users
  // (Server should authorize via superadmin claim; tenantId in base may be ignored.)
  // ─────────────────────────────────────────────
  Uri hqListSuperAdmins() => _uri('hq/superadmins'); // GET
  Uri hqSetSuperAdmin(String uid) =>
      _uri('hq/superadmins/$uid'); // POST {value: bool}

  Uri hqUsers({String? tenantId, String? search, int limit = 50}) => _uri(
    'hq/users', // GET
    query: {
      if (tenantId != null && tenantId.isNotEmpty) 'tenantId': tenantId,
      if (search != null && search.isNotEmpty) 'search': search,
      'limit': '$limit',
    },
  );

  Uri hqUserMemberships(String uid) => _uri('hq/users/$uid/memberships'); // GET

  // ─────────────────────────────────────────────
  // 🏢 Tenancy (Tenant Scoped) – membership invite/revoke
  // (Kept for backwards compatibility with older callers.)
  // ─────────────────────────────────────────────
  Uri inviteToTenant() =>
      _uri('users/invite'); // POST {email, role?, forceResend?}
  Uri revokeFromTenant(String uid) => _uri('users/$uid'); // DELETE

  // ─────────────────────────────────────────────
  // 🏢 Tenants (management APIs) – owner/admins/status/config
  // ─────────────────────────────────────────────
  Uri listTenants() => _uri('tenants'); // GET
  Uri getTenant(String slug) => _uri('tenants/$slug'); // GET
  Uri createTenant() => _uri('tenants'); // POST
  Uri updateTenant(String slug) => _uri('tenants/$slug'); // PATCH
  Uri setTenantStatus(String slug) =>
      _uri('tenants/$slug/status'); // POST {status}
  Uri transferTenantOwner(String slug) =>
      _uri('tenants/$slug/owner'); // POST {newOwnerUid}

  // admins under a tenant
  Uri listTenantAdmins(String slug) => _uri('tenants/$slug/admins'); // GET
  Uri addTenantAdmin(String slug) =>
      _uri('tenants/$slug/admins'); // POST {uid|email, role}
  Uri removeTenantAdmin(String slug, String uid) =>
      _uri('tenants/$slug/admins/$uid'); // DELETE (optional ?soft=1)

  // optional: flags/config knobs under a tenant
  Uri setTenantFlag(String slug, String key) =>
      _uri('tenants/$slug/flags/$key'); // PATCH {value}

  // ─────────────────────────────────────────────
  // 🔐 Auth (Session + Dev)
  // ─────────────────────────────────────────────
  Uri login() => _uri('auth/login');
  Uri syncClaims() => _uri('auth/session/sync-claims');
  Uri getCurrentUser() => _uri('auth/session/me');
  Uri checkUserStatus() => _uri('auth/session/check-user-status');
  Uri sendPasswordResetEmail() => _uri('auth/session/send-password-reset');

  // ─────────────────────────────────────────────
  // 👥 Auth Users (tenant-scoped directory)
  // ─────────────────────────────────────────────
  Uri getAllUsers() => _uri('auth_users'); // GET
  Uri getUserById(String uid) => _uri('auth_users/$uid'); // GET
  Uri inviteUser() => _uri(
    'auth_users/invite',
  ); // POST {email|phoneNumber, role?, forceResend?}
  Uri deleteUser(String uid) =>
      _uri('auth_users/$uid'); // DELETE (removes tenant membership)
  Uri updateUser(String uid) => _uri('auth_users/$uid'); // PATCH {status?}

  // subresources
  Uri updateAuthUserRole(String uid) =>
      _uri('auth_users/$uid/role'); // PATCH {role}
  Uri updateAuthUserStores(String uid) =>
      _uri('auth_users/$uid/stores'); // PATCH {stores: []}
  Uri updateAuthUserProfile(String uid) => _uri(
    'auth_users/$uid/profile',
  ); // PATCH {displayName?, phoneNumber?, avatarUrl?}

  // ─────────────────────────────────────────────
  // 📦 Inventory
  // ─────────────────────────────────────────────
  Uri inventory(String itemType) =>
      _uri('inventory', query: {'type': itemType});
  Uri createItem() => _uri('inventory');
  Uri itemById(String id, [String? itemType]) => _uri(
    'inventory/$id',
    query: itemType != null ? {'type': itemType} : null,
  );

  // ─────────────────────────────────────────────
  // ⚙️ Preferences
  // ─────────────────────────────────────────────
  Uri preferenceField(String type, String field) =>
      _uri('preferences/$type/$field');

  // ─────────────────────────────────────────────
  // 📍 Typed Inventory Location Routes
  // ─────────────────────────────────────────────
  Uri getTypedLocationsUri(InventoryLocationType type) =>
      _uri('inventory-locations', query: {'type': type.asString});
  Uri addTypedLocationWithIdUri(InventoryLocationType type, String id) =>
      _uri('inventory-locations/${type.asString}/$id');
  Uri deleteTypedLocationUri(InventoryLocationType type, String id) =>
      _uri('inventory-locations/${type.asString}/$id');
  Uri addLocationUri() => _uri('inventory-locations');

  // ─────────────────────────────────────────────
  // 🧪 Batches
  // ─────────────────────────────────────────────
  Uri createBatchUri(String storeId) =>
      _uri('stores/${Uri.encodeComponent(storeId)}/batches');
  Uri updateBatchUri(String storeId, String batchId) =>
      _uri('stores/${Uri.encodeComponent(storeId)}/batches/$batchId');
  Uri deleteBatchUri(String storeId, String batchId) =>
      _uri('stores/${Uri.encodeComponent(storeId)}/batches/$batchId');
}
