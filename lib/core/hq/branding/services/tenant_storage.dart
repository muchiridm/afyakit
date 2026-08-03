// lib/core/hq/branding/services/tenant_storage.dart

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Types of web assets we manage per tenant.
///
/// Paths follow:
/// public/{tenantId}/branding/web/{filename}
enum TenantWebAssetType {
  favicon, // favicon.png
  icon192, // icon-192.png
  icon512, // icon-512.png
  maskableIcon192, // icon-maskable-192.png
  maskableIcon512, // icon-maskable-512.png
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
    case TenantWebAssetType.maskableIcon192:
      return 'icon-maskable-192.png';
    case TenantWebAssetType.maskableIcon512:
      return 'icon-maskable-512.png';
  }
}

/// Helper: default content type for each web asset type.
String tenantWebAssetContentType(TenantWebAssetType type) {
  switch (type) {
    case TenantWebAssetType.favicon:
    case TenantWebAssetType.icon192:
    case TenantWebAssetType.icon512:
    case TenantWebAssetType.maskableIcon192:
    case TenantWebAssetType.maskableIcon512:
      return 'image/png';
  }
}

/// Helper: storage path under the app bucket.
String tenantWebAssetPath(String tenantId, TenantWebAssetType type) {
  final cleanTenantId = tenantId.trim();

  if (cleanTenantId.isEmpty) {
    throw ArgumentError.value(tenantId, 'tenantId', 'tenantId cannot be empty');
  }

  return 'public/$cleanTenantId/branding/web/${tenantWebAssetFilename(type)}';
}

/// If you ever want per-tenant buckets, you can change this.
///
/// For now, all tenants share the app's default bucket.
FirebaseStorage storageForTenant(String tenantId) {
  return FirebaseStorage.instance;
}

/// Service that uploads / deletes tenant web assets in Firebase Storage.
class TenantStorageService {
  TenantStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Reference _refForWebAsset(String tenantId, TenantWebAssetType type) {
    final path = tenantWebAssetPath(tenantId, type);
    return _storage.ref().child(path);
  }

  /// Upload raw bytes for a tenant web asset.
  ///
  /// On web you’ll typically use `FilePicker` / `<input>` to get the bytes.
  Future<void> uploadWebAssetBytes({
    required String tenantId,
    required TenantWebAssetType type,
    required Uint8List bytes,
    String? contentType,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes.length, 'bytes', 'bytes cannot be empty');
    }

    final ref = _refForWebAsset(tenantId, type);

    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType ?? tenantWebAssetContentType(type),
        cacheControl: 'public, max-age=300',
      ),
    );
  }

  /// Delete a specific tenant web asset. No-op if it doesn't exist.
  Future<void> deleteWebAsset({
    required String tenantId,
    required TenantWebAssetType type,
  }) async {
    final ref = _refForWebAsset(tenantId, type);

    try {
      await ref.delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      rethrow;
    }
  }

  /// Check if a tenant web asset currently exists.
  Future<bool> webAssetExists({
    required String tenantId,
    required TenantWebAssetType type,
  }) async {
    final ref = _refForWebAsset(tenantId, type);

    try {
      await ref.getDownloadURL();
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return false;
      rethrow;
    }
  }

  /// Get a download URL, useful for previews in the HQ editor.
  Future<String?> getWebAssetDownloadUrl({
    required String tenantId,
    required TenantWebAssetType type,
  }) async {
    final ref = _refForWebAsset(tenantId, type);

    try {
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return null;
      rethrow;
    }
  }
}
