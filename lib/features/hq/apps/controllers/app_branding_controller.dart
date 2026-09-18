import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/branding/services/branding_storage.dart';
import 'package:afyakit/features/hq/apps/providers/hq_app_profiles_provider.dart';
import 'package:afyakit/features/hq/apps/services/app_profile_service.dart';

class AppBrandingState {
  final bool savingProfile;
  final bool uploadingAsset;
  final String? error;

  const AppBrandingState({
    this.savingProfile = false,
    this.uploadingAsset = false,
    this.error,
  });

  bool get busy => savingProfile || uploadingAsset;

  AppBrandingState copyWith({
    bool? savingProfile,
    bool? uploadingAsset,
    Object? error = _unset,
  }) {
    return AppBrandingState(
      savingProfile: savingProfile ?? this.savingProfile,
      uploadingAsset: uploadingAsset ?? this.uploadingAsset,
      error: error == _unset ? this.error : error as String?,
    );
  }

  static const Object _unset = Object();
}

final appBrandingControllerProvider =
    AutoDisposeStateNotifierProvider<AppBrandingController, AppBrandingState>(
      (ref) => AppBrandingController(ref),
    );

class AppBrandingController extends StateNotifier<AppBrandingState> {
  AppBrandingController(this._ref) : super(const AppBrandingState());

  final Ref _ref;

  Future<AppProfileService> get _service {
    return _ref.read(appProfileServiceProvider.future);
  }

  BrandingStorageService get _storage {
    return _ref.read(brandingStorageServiceProvider);
  }

  Future<bool> saveProfileBranding({
    required String tenantId,
    required String appId,
    required String seoTitle,
    required String seoDescription,
    required String tagline,
    required String primaryColorHex,
  }) async {
    state = state.copyWith(savingProfile: true, error: null);

    try {
      final service = await _service;

      final current = await service.getAppProfile(
        tenantId: tenantId,
        appId: appId,
      );

      final profile = <String, dynamic>{
        'tagline': tagline.trim(),
        'seoTitle': seoTitle.trim(),
        'seoDescription': seoDescription.trim(),
        'website': current.details.website,
        'email': current.details.email,
        'supportNote': current.details.supportNote,
      };

      final color = primaryColorHex.trim();

      await service.updateAppProfile(
        tenantId: tenantId,
        appId: appId,
        primaryColorHex: color.isEmpty ? current.primaryColorHex : color,
        profile: profile,
      );

      _invalidateApps(tenantId);

      state = state.copyWith(savingProfile: false, error: null);

      return true;
    } catch (error) {
      state = state.copyWith(savingProfile: false, error: error.toString());

      return false;
    }
  }

  Future<bool> uploadWebAsset({
    required String tenantId,
    required String appId,
    required BrandingWebAssetType type,
    required Uint8List bytes,
  }) async {
    state = state.copyWith(uploadingAsset: true, error: null);

    try {
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

      if (url == null || url.trim().isEmpty) {
        throw StateError('Upload succeeded but download URL was null or empty');
      }

      final service = await _service;

      await service.updateAppWebAsset(
        tenantId: tenantId,
        appId: appId,
        assetKey: type.key,
        downloadUrl: url,
      );

      _invalidateApps(tenantId);

      state = state.copyWith(uploadingAsset: false, error: null);

      return true;
    } catch (error) {
      state = state.copyWith(uploadingAsset: false, error: error.toString());

      return false;
    }
  }

  Future<bool> deleteWebAsset({
    required String tenantId,
    required String appId,
    required BrandingWebAssetType type,
  }) async {
    state = state.copyWith(uploadingAsset: true, error: null);

    try {
      await _storage.deleteWebAsset(
        tenantId: tenantId,
        appId: appId,
        type: type,
      );

      final service = await _service;

      final current = await service.getAppProfile(
        tenantId: tenantId,
        appId: appId,
      );

      final logos = Map<String, String>.from(current.assets.logos);

      logos.remove(type.key);

      await service.updateAppProfile(
        tenantId: tenantId,
        appId: appId,
        assets: <String, dynamic>{
          'bucket': current.assets.bucket,
          'version': current.assets.version + 1,
          'logos': logos,
        },
      );

      _invalidateApps(tenantId);

      state = state.copyWith(uploadingAsset: false, error: null);

      return true;
    } catch (error) {
      state = state.copyWith(uploadingAsset: false, error: error.toString());

      return false;
    }
  }

  void _invalidateApps(String tenantId) {
    _ref.invalidate(hqAppProfilesProvider(tenantId));
  }
}
