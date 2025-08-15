import 'package:afyakit/features/inventory_locations/inventory_location_type_enum.dart';
import 'package:afyakit/shared/api/api_client_base.dart';
import 'package:flutter/material.dart';

class ApiRoutes {
  final String tenantId;
  ApiRoutes(this.tenantId);

  Uri _uri(String path, {Map<String, String>? query}) {
    final base = apiBaseUrl(tenantId);
    final uri = Uri.parse('$base/$path');
    debugPrint('🧭 Building URI → base: $base | path: $path → $uri');
    return query != null ? uri.replace(queryParameters: query) : uri;
  }

  // ─────────────────────────────────────────────
  // 🔐 Auth (Session + Dev)
  // ─────────────────────────────────────────────
  Uri login() => _uri('auth/login');
  Uri syncClaims() => _uri('auth/session/sync-claims');
  Uri getCurrentUser() => _uri('auth/session/me');
  Uri checkUserStatus() => _uri('auth/session/check-user-status');
  Uri sendPasswordResetEmail() => _uri('auth/session/send-password-reset');

  // ─────────────────────────────────────────────
  // 👥 Auth Users (single source of truth on FE)
  // ─────────────────────────────────────────────
  Uri getAllUsers() => _uri('auth_users');
  Uri getUserById(String uid) => _uri('auth_users/$uid');
  Uri inviteUser() => _uri('auth_users/invite');
  Uri deleteUser(String uid) => _uri('auth_users/$uid');
  Uri updateUser(String uid) => _uri('auth_users/$uid');

  // Subresources (compat fallbacks; still under auth_users)
  Uri updateAuthUserRole(String uid) => _uri('auth_users/$uid/role');
  Uri updateAuthUserStores(String uid) => _uri('auth_users/$uid/stores');
  Uri updateAuthUserProfile(String uid) => _uri('auth_users/$uid/profile');

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
