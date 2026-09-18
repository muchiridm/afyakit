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

extension BrandingWebAssetTypeX on BrandingWebAssetType {
  String get key {
    return switch (this) {
      BrandingWebAssetType.favicon => 'favicon',
      BrandingWebAssetType.icon192 => 'icon192',
      BrandingWebAssetType.icon512 => 'icon512',
      BrandingWebAssetType.maskableIcon192 => 'maskableIcon192',
      BrandingWebAssetType.maskableIcon512 => 'maskableIcon512',
    };
  }

  String get filename {
    return switch (this) {
      BrandingWebAssetType.favicon => 'favicon.png',
      BrandingWebAssetType.icon192 => 'icon-192.png',
      BrandingWebAssetType.icon512 => 'icon-512.png',
      BrandingWebAssetType.maskableIcon192 => 'icon-maskable-192.png',
      BrandingWebAssetType.maskableIcon512 => 'icon-maskable-512.png',
    };
  }

  String get contentType => 'image/png';
}

final brandingStorageServiceProvider = Provider<BrandingStorageService>((ref) {
  return BrandingStorageService(storage: FirebaseStorage.instance);
});

class BrandingStorageService {
  BrandingStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<void> uploadWebAssetBytes({
    required String tenantId,
    required String appId,
    required BrandingWebAssetType type,
    required Uint8List bytes,
    String? contentType,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes.length, 'bytes', 'bytes cannot be empty');
    }

    final ref = _reference(tenantId: tenantId, appId: appId, type: type);

    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType ?? type.contentType,
        cacheControl: 'public, max-age=300',
      ),
    );
  }

  Future<void> deleteWebAsset({
    required String tenantId,
    required String appId,
    required BrandingWebAssetType type,
  }) async {
    final ref = _reference(tenantId: tenantId, appId: appId, type: type);

    try {
      await ref.delete();
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return;
      }

      rethrow;
    }
  }

  Future<bool> webAssetExists({
    required String tenantId,
    required String appId,
    required BrandingWebAssetType type,
  }) async {
    final ref = _reference(tenantId: tenantId, appId: appId, type: type);

    try {
      await ref.getDownloadURL();
      return true;
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return false;
      }

      rethrow;
    }
  }

  Future<String?> getWebAssetDownloadUrl({
    required String tenantId,
    required String appId,
    required BrandingWebAssetType type,
  }) async {
    final ref = _reference(tenantId: tenantId, appId: appId, type: type);

    try {
      return await ref.getDownloadURL();
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return null;
      }

      rethrow;
    }
  }

  Reference _reference({
    required String tenantId,
    required String appId,
    required BrandingWebAssetType type,
  }) {
    return _storage.ref().child(
      brandingWebAssetPath(tenantId: tenantId, appId: appId, type: type),
    );
  }
}

String brandingWebAssetPath({
  required String tenantId,
  required String appId,
  required BrandingWebAssetType type,
}) {
  final cleanTenantId = _cleanId(tenantId, fieldName: 'tenantId');

  final cleanAppId = _cleanId(appId, fieldName: 'appId');

  return 'public/'
      '$cleanTenantId/'
      'apps/'
      '$cleanAppId/'
      'branding/'
      'web/'
      '${type.filename}';
}

String _cleanId(String value, {required String fieldName}) {
  final clean = value.trim().toLowerCase();

  if (clean.isEmpty) {
    throw ArgumentError.value(value, fieldName, '$fieldName cannot be empty');
  }

  return clean;
}
