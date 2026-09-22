import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/branding/services/branding_storage.dart';
import 'package:afyakit/features/hq/apps/providers/hq_app_profiles_provider.dart';
import 'package:afyakit/features/hq/apps/services/app_profile_service.dart';

class AppBrandingState {
  const AppBrandingState({
    this.savingColor = false,
    this.changingAsset = false,
    this.error,
  });

  final bool savingColor;
  final bool changingAsset;
  final String? error;

  bool get busy => savingColor || changingAsset;

  static const Object _unset = Object();

  AppBrandingState copyWith({
    bool? savingColor,
    bool? changingAsset,
    Object? error = _unset,
  }) {
    return AppBrandingState(
      savingColor: savingColor ?? this.savingColor,
      changingAsset: changingAsset ?? this.changingAsset,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}

final appBrandingControllerProvider =
    AutoDisposeStateNotifierProvider<AppBrandingController, AppBrandingState>(
      (ref) => AppBrandingController(ref),
    );

class AppBrandingController extends StateNotifier<AppBrandingState> {
  AppBrandingController(this._ref) : super(const AppBrandingState());

  final Ref _ref;

  Future<AppProfileService> get _service =>
      _ref.read(appProfileServiceProvider.future);

  BrandingStorageService get _storage =>
      _ref.read(brandingStorageServiceProvider);

  // ─────────────────────────────────────────
  // Accent colour
  // ─────────────────────────────────────────

  Future<bool> saveColor({
    required String tenantId,
    required String appId,
    required String primaryColorHex,
  }) async {
    if (state.busy) return false;

    final color = primaryColorHex.trim().toUpperCase();

    if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(color)) {
      state = state.copyWith(error: 'Enter a six-digit colour, e.g. #2196F3.');
      return false;
    }

    state = state.copyWith(savingColor: true, error: null);

    try {
      final service = await _service;

      // Never send `profile` from Branding.
      await service.updateAppProfile(
        tenantId: tenantId,
        appId: appId,
        primaryColorHex: color,
      );

      _invalidateApps(tenantId);

      state = state.copyWith(savingColor: false, error: null);
      return true;
    } catch (error) {
      state = state.copyWith(savingColor: false, error: error.toString());
      return false;
    }
  }

  // ─────────────────────────────────────────
  // Primary / secondary logos
  // ─────────────────────────────────────────

  Future<bool> uploadLogo({
    required String tenantId,
    required String appId,
    required BrandingLogoType type,
    required Uint8List bytes,
  }) {
    return _changeAsset(
      tenantId: tenantId,
      operation: () async {
        _validatePng(bytes, maxBytes: 5 * 1024 * 1024);

        await _storage.uploadLogoBytes(
          tenantId: tenantId,
          appId: appId,
          type: type,
          bytes: bytes,
        );

        final url = await _storage.getLogoDownloadUrl(
          tenantId: tenantId,
          appId: appId,
          type: type,
        );

        await _saveAssetUrl(
          tenantId: tenantId,
          appId: appId,
          key: type.key,
          url: url,
        );
      },
    );
  }

  Future<bool> deleteLogo({
    required String tenantId,
    required String appId,
    required BrandingLogoType type,
  }) {
    return _changeAsset(
      tenantId: tenantId,
      operation: () async {
        await _storage.deleteLogo(tenantId: tenantId, appId: appId, type: type);

        await _removeAssetKey(tenantId: tenantId, appId: appId, key: type.key);
      },
    );
  }

  // ─────────────────────────────────────────
  // Favicon / PWA icons
  // ─────────────────────────────────────────

  Future<bool> uploadWebAsset({
    required String tenantId,
    required String appId,
    required BrandingWebAssetType type,
    required Uint8List bytes,
  }) {
    return _changeAsset(
      tenantId: tenantId,
      operation: () async {
        _validatePng(bytes, maxBytes: 2 * 1024 * 1024);

        await _storage.uploadWebAssetBytes(
          tenantId: tenantId,
          appId: appId,
          type: type,
          bytes: bytes,
        );

        final url = await _storage.getWebAssetDownloadUrl(
          tenantId: tenantId,
          appId: appId,
          type: type,
        );

        await _saveAssetUrl(
          tenantId: tenantId,
          appId: appId,
          key: type.key,
          url: url,
        );
      },
    );
  }

  Future<bool> deleteWebAsset({
    required String tenantId,
    required String appId,
    required BrandingWebAssetType type,
  }) {
    return _changeAsset(
      tenantId: tenantId,
      operation: () async {
        await _storage.deleteWebAsset(
          tenantId: tenantId,
          appId: appId,
          type: type,
        );

        await _removeAssetKey(tenantId: tenantId, appId: appId, key: type.key);
      },
    );
  }

  // ─────────────────────────────────────────
  // Shared asset workflow
  // ─────────────────────────────────────────

  Future<bool> _changeAsset({
    required String tenantId,
    required Future<void> Function() operation,
  }) async {
    if (state.busy) return false;

    state = state.copyWith(changingAsset: true, error: null);

    try {
      await operation();

      _invalidateApps(tenantId);

      state = state.copyWith(changingAsset: false, error: null);
      return true;
    } catch (error) {
      state = state.copyWith(changingAsset: false, error: error.toString());
      return false;
    }
  }

  Future<void> _saveAssetUrl({
    required String tenantId,
    required String appId,
    required String key,
    required String? url,
  }) async {
    if (url == null || url.trim().isEmpty) {
      throw StateError(
        'Image uploaded, but its download URL was not returned.',
      );
    }

    final service = await _service;

    // Existing service method updates an arbitrary
    // assets.logos[key], not just web icons.
    await service.updateAppWebAsset(
      tenantId: tenantId,
      appId: appId,
      assetKey: key,
      downloadUrl: url,
    );
  }

  Future<void> _removeAssetKey({
    required String tenantId,
    required String appId,
    required String key,
  }) async {
    final service = await _service;

    final current = await service.getAppProfile(
      tenantId: tenantId,
      appId: appId,
    );

    final logos = Map<String, String>.from(current.assets.logos)..remove(key);

    await service.updateAppProfile(
      tenantId: tenantId,
      appId: appId,
      assets: <String, dynamic>{
        'bucket': current.assets.bucket,
        'version': current.assets.version + 1,
        'logos': logos,
      },
    );
  }

  void _validatePng(Uint8List bytes, {required int maxBytes}) {
    const pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];

    if (bytes.length < pngSignature.length) {
      throw ArgumentError('Invalid PNG image.');
    }

    if (bytes.length > maxBytes) {
      throw ArgumentError(
        'Image exceeds the ${maxBytes ~/ (1024 * 1024)} MB limit.',
      );
    }

    for (var i = 0; i < pngSignature.length; i++) {
      if (bytes[i] != pngSignature[i]) {
        throw ArgumentError('Only PNG images are supported.');
      }
    }
  }

  void _invalidateApps(String tenantId) {
    _ref.invalidate(hqAppProfilesProvider(tenantId));
  }
}
