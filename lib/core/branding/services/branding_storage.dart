// lib/core/branding/services/branding_storage.dart

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BrandingWebAssetType {
  favicon,
  icon192,
  icon512,
  maskableIcon192,
  maskableIcon512,
}

enum BrandingLogoType { primary, secondary }

extension BrandingWebAssetTypeX on BrandingWebAssetType {
  String get key => switch (this) {
    BrandingWebAssetType.favicon => 'favicon',
    BrandingWebAssetType.icon192 => 'icon192',
    BrandingWebAssetType.icon512 => 'icon512',
    BrandingWebAssetType.maskableIcon192 => 'maskableIcon192',
    BrandingWebAssetType.maskableIcon512 => 'maskableIcon512',
  };

  String get filename => switch (this) {
    BrandingWebAssetType.favicon => 'favicon.png',
    BrandingWebAssetType.icon192 => 'icon-192.png',
    BrandingWebAssetType.icon512 => 'icon-512.png',
    BrandingWebAssetType.maskableIcon192 => 'icon-maskable-192.png',
    BrandingWebAssetType.maskableIcon512 => 'icon-maskable-512.png',
  };

  String get contentType => 'image/png';
}

extension BrandingLogoTypeX on BrandingLogoType {
  String get key => switch (this) {
    BrandingLogoType.primary => 'primary',
    BrandingLogoType.secondary => 'secondary',
  };

  String get filename => switch (this) {
    BrandingLogoType.primary => 'logo-primary.png',
    BrandingLogoType.secondary => 'logo-secondary.png',
  };

  String get contentType => 'image/png';
}

final brandingStorageServiceProvider = Provider<BrandingStorageService>((ref) {
  return BrandingStorageService(storage: FirebaseStorage.instance);
});

class BrandingStorageService {
  BrandingStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  // ─────────────────────────────────────────
  // Web assets
  // ─────────────────────────────────────────

  Future<void> uploadWebAssetBytes({
    required String tenantId,
    required String appId,
    required BrandingWebAssetType type,
    required Uint8List bytes,
    String? contentType,
  }) {
    return _upload(
      path: brandingWebAssetPath(tenantId: tenantId, appId: appId, type: type),
      bytes: bytes,
      contentType: contentType ?? type.contentType,
    );
  }

  Future<void> deleteWebAsset({
    required String tenantId,
    required String appId,
    required BrandingWebAssetType type,
  }) {
    return _delete(
      brandingWebAssetPath(tenantId: tenantId, appId: appId, type: type),
    );
  }

  Future<bool> webAssetExists({
    required String tenantId,
    required String appId,
    required BrandingWebAssetType type,
  }) {
    return _exists(
      brandingWebAssetPath(tenantId: tenantId, appId: appId, type: type),
    );
  }

  Future<String?> getWebAssetDownloadUrl({
    required String tenantId,
    required String appId,
    required BrandingWebAssetType type,
  }) {
    return _downloadUrl(
      brandingWebAssetPath(tenantId: tenantId, appId: appId, type: type),
    );
  }

  // ─────────────────────────────────────────
  // Logos
  // ─────────────────────────────────────────

  Future<void> uploadLogoBytes({
    required String tenantId,
    required String appId,
    required BrandingLogoType type,
    required Uint8List bytes,
    String? contentType,
  }) {
    return _upload(
      path: brandingLogoPath(tenantId: tenantId, appId: appId, type: type),
      bytes: bytes,
      contentType: contentType ?? type.contentType,
    );
  }

  Future<void> deleteLogo({
    required String tenantId,
    required String appId,
    required BrandingLogoType type,
  }) {
    return _delete(
      brandingLogoPath(tenantId: tenantId, appId: appId, type: type),
    );
  }

  Future<bool> logoExists({
    required String tenantId,
    required String appId,
    required BrandingLogoType type,
  }) {
    return _exists(
      brandingLogoPath(tenantId: tenantId, appId: appId, type: type),
    );
  }

  Future<String?> getLogoDownloadUrl({
    required String tenantId,
    required String appId,
    required BrandingLogoType type,
  }) {
    return _downloadUrl(
      brandingLogoPath(tenantId: tenantId, appId: appId, type: type),
    );
  }

  // ─────────────────────────────────────────
  // Shared Storage operations
  // ─────────────────────────────────────────

  Future<void> _upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes.length, 'bytes', 'bytes cannot be empty');
    }

    await _storage
        .ref()
        .child(path)
        .putData(
          bytes,
          SettableMetadata(
            contentType: contentType,
            cacheControl: 'public, max-age=300',
          ),
        );
  }

  Future<void> _delete(String path) async {
    try {
      await _storage.ref().child(path).delete();
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') return;
      rethrow;
    }
  }

  Future<bool> _exists(String path) async {
    try {
      await _storage.ref().child(path).getMetadata();
      return true;
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') return false;
      rethrow;
    }
  }

  Future<String?> _downloadUrl(String path) async {
    try {
      return await _storage.ref().child(path).getDownloadURL();
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') return null;
      rethrow;
    }
  }
}

// ─────────────────────────────────────────
// Canonical Storage paths
// ─────────────────────────────────────────

String brandingRoot({required String tenantId, required String appId}) {
  final tenant = _cleanId(tenantId, fieldName: 'tenantId');

  final app = _cleanId(appId, fieldName: 'appId');

  return 'public/$tenant/$app/branding';
}

String brandingLogoPath({
  required String tenantId,
  required String appId,
  required BrandingLogoType type,
}) {
  final root = brandingRoot(tenantId: tenantId, appId: appId);

  return '$root/logos/${type.filename}';
}

String brandingWebAssetPath({
  required String tenantId,
  required String appId,
  required BrandingWebAssetType type,
}) {
  final root = brandingRoot(tenantId: tenantId, appId: appId);

  return '$root/web/${type.filename}';
}

String _cleanId(String value, {required String fieldName}) {
  final clean = value.trim().toLowerCase();

  if (clean.isEmpty || !RegExp(r'^[a-z0-9_-]+$').hasMatch(clean)) {
    throw ArgumentError.value(value, fieldName, 'Invalid $fieldName');
  }

  return clean;
}
