// lib/hq/tenants/controllers/tenant_branding_controller.dart

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/tenants/models/tenant_profile.dart';
import 'package:afyakit/hq/tenants/services/tenant_profile_service.dart';
import 'package:afyakit/hq/tenants/services/tenant_storage.dart';

class TenantBrandingState {
  final bool savingProfile;
  final bool uploadingAsset;
  final String? error;

  const TenantBrandingState({
    this.savingProfile = false,
    this.uploadingAsset = false,
    this.error,
  });

  TenantBrandingState copyWith({
    bool? savingProfile,
    bool? uploadingAsset,
    String? error,
  }) {
    return TenantBrandingState(
      savingProfile: savingProfile ?? this.savingProfile,
      uploadingAsset: uploadingAsset ?? this.uploadingAsset,
      error: error,
    );
  }
}

final tenantBrandingControllerProvider =
    AutoDisposeStateNotifierProvider<
      TenantBrandingController,
      TenantBrandingState
    >((ref) {
      return TenantBrandingController(ref);
    });

class TenantBrandingController extends StateNotifier<TenantBrandingState> {
  TenantBrandingController(this._ref) : super(const TenantBrandingState());

  final AutoDisposeStateNotifierProviderRef<
    TenantBrandingController,
    TenantBrandingState
  >
  _ref;

  Future<TenantProfile> _loadProfile(String slug) async {
    final svc = await _ref.read(tenantProfileServiceProvider.future);
    return svc.getTenantProfile(slug);
  }

  /// Update SEO + tagline + primary color from tenant admin.
  Future<bool> saveProfileBranding({
    required String slug,
    required String seoTitle,
    required String seoDescription,
    required String tagline,
    required String primaryColorHex,
  }) async {
    state = state.copyWith(savingProfile: true, error: null);
    try {
      final svc = await _ref.read(tenantProfileServiceProvider.future);

      // Load existing profile to merge in other fields
      final current = await _loadProfile(slug);

      final profile = <String, dynamic>{
        // keep existing profile fields, then override the branding ones
        'tagline': tagline,
        'website': current.details.website,
        'email': current.details.email,
        'whatsapp': current.details.whatsapp,
        'currency': current.details.currency,
        'seoTitle': seoTitle,
        'seoDescription': seoDescription,
        if (current.details.compliance.isNotEmpty)
          'compliance': current.details.compliance,
        if (current.details.payments.isNotEmpty)
          'payments': current.details.payments,
      };

      await svc.updateTenantProfile(
        slug: slug,
        primaryColorHex: primaryColorHex.trim().isEmpty
            ? current.primaryColorHex
            : primaryColorHex,
        profile: profile,
      );

      state = state.copyWith(savingProfile: false, error: null);
      return true;
    } catch (e) {
      state = state.copyWith(savingProfile: false, error: e.toString());
      return false;
    }
  }

  /// Upload favicon / icons. Bumps assets.version to bust cache.
  Future<bool> uploadWebAsset({
    required String slug,
    required TenantWebAssetType type,
    required Uint8List bytes,
  }) async {
    state = state.copyWith(uploadingAsset: true, error: null);
    try {
      final storage = TenantStorageService();
      await storage.uploadWebAssetBytes(
        tenantSlug: slug,
        type: type,
        bytes: bytes,
      );

      // bump version so URLs change and caches refresh
      final svc = await _ref.read(tenantProfileServiceProvider.future);
      final current = await _loadProfile(slug);
      await svc.updateTenantProfile(
        slug: slug,
        assets: {
          'bucket': current.assets.bucket,
          'version': current.assets.version + 1,
        },
      );

      state = state.copyWith(uploadingAsset: false, error: null);
      return true;
    } catch (e) {
      state = state.copyWith(uploadingAsset: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteWebAsset({
    required String slug,
    required TenantWebAssetType type,
  }) async {
    state = state.copyWith(uploadingAsset: true, error: null);
    try {
      final storage = TenantStorageService();
      await storage.deleteWebAsset(tenantSlug: slug, type: type);

      // bump version again to force browsers to drop old cached icon
      final svc = await _ref.read(tenantProfileServiceProvider.future);
      final current = await _loadProfile(slug);
      await svc.updateTenantProfile(
        slug: slug,
        assets: {
          'bucket': current.assets.bucket,
          'version': current.assets.version + 1,
        },
      );

      state = state.copyWith(uploadingAsset: false, error: null);
      return true;
    } catch (e) {
      state = state.copyWith(uploadingAsset: false, error: e.toString());
      return false;
    }
  }
}
