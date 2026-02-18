// lib/hq/tenants/services/tenant_storage.dart

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Types of web assets we manage per tenant.
/// Paths follow: public/{tenantSlug}/web/{filename}.png
enum TenantWebAssetType {
  favicon, // favicon.png
  icon192, // icon-192.png
  icon512, // icon-512.png
}

/// Helper: filename for each web asset type.
String tenantWebAssetFilename(TenantWebAssetType type) {
  switch (type) {
    case TenantWebAssetType.favicon:
      return 'favicon.png';
    case TenantWebAssetType.icon192:
      return 'icon-192.png';
    case TenantWebAssetType.icon512:
      return 'icon-512.png';
  }
}

/// Helper: storage path under the app bucket.
String tenantWebAssetPath(String tenantSlug, TenantWebAssetType type) {
  return 'public/$tenantSlug/web/${tenantWebAssetFilename(type)}';
}

/// If you ever want per-tenant buckets, you can change this.
/// For now, all tenants share the app's default bucket.
FirebaseStorage storageForTenant(String tenantSlug) {
  return FirebaseStorage.instance;
}

/// Service that uploads / deletes tenant web assets in Firebase Storage.
class TenantStorageService {
  TenantStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Reference _refForWebAsset(String tenantSlug, TenantWebAssetType type) {
    final path = tenantWebAssetPath(tenantSlug, type);
    return _storage.ref().child(path);
  }

  /// Upload raw bytes for a tenant web asset (favicon or icons).
  ///
  /// On web you’ll typically use `FilePicker` / `<input>` to get the bytes.
  Future<void> uploadWebAssetBytes({
    required String tenantSlug,
    required TenantWebAssetType type,
    required Uint8List bytes,
    String contentType = 'image/png',
  }) async {
    final ref = _refForWebAsset(tenantSlug, type);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
  }

  /// Delete a specific tenant web asset. No-op if it doesn't exist.
  Future<void> deleteWebAsset({
    required String tenantSlug,
    required TenantWebAssetType type,
  }) async {
    final ref = _refForWebAsset(tenantSlug, type);
    try {
      await ref.delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        // ignore missing files
        return;
      }
      rethrow;
    }
  }

  /// Check if a tenant web asset currently exists.
  Future<bool> webAssetExists({
    required String tenantSlug,
    required TenantWebAssetType type,
  }) async {
    final ref = _refForWebAsset(tenantSlug, type);
    try {
      await ref.getDownloadURL();
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return false;
      rethrow;
    }
  }

  /// Get a download URL (useful for previews in the HQ editor).
  Future<String?> getWebAssetDownloadUrl({
    required String tenantSlug,
    required TenantWebAssetType type,
  }) async {
    final ref = _refForWebAsset(tenantSlug, type);
    try {
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return null;
      rethrow;
    }
  }
}
