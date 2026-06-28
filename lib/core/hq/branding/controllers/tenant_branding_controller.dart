import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/hq/tenants/services/tenant_service.dart';
import 'package:afyakit/core/hq/branding/services/tenant_storage.dart';

// Optional (only if you have it)
import 'package:afyakit/core/hq/tenants/providers/hq_tenants_provider.dart';

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
    >((ref) => TenantBrandingController(ref));

class TenantBrandingController extends StateNotifier<TenantBrandingState> {
  TenantBrandingController(this._ref) : super(const TenantBrandingState());

  final AutoDisposeRef _ref;

  Future<TenantService> _svc() => _ref.read(tenantServiceProvider.future);

  // ─────────────────────────────────────────────
  // Profile branding
  // ─────────────────────────────────────────────

  Future<bool> saveProfileBranding({
    required String tenantId,
    required String seoTitle,
    required String seoDescription,
    required String tagline,
    required String primaryColorHex,
  }) async {
    state = state.copyWith(savingProfile: true, error: null);
    try {
      final svc = await _svc();

      // Load existing profile so we can merge safely without nuking fields.
      final current = await svc.getTenantProfile(tenantId);

      final profile = <String, dynamic>{
        // preserve existing values unless we're explicitly overwriting
        'tagline': tagline.trim(),
        'seoTitle': seoTitle.trim(),
        'seoDescription': seoDescription.trim(),

        // keep existing details you already model/use
        'website': current.details.website,
        'email': current.details.email,
        'whatsapp': current.details.whatsapp,
        'currency': current.details.currency,

        if (current.details.compliance.isNotEmpty)
          'compliance': current.details.compliance,
        if (current.details.payments.isNotEmpty)
          'payments': current.details.payments,
      };

      final color = primaryColorHex.trim();
      await svc.updateTenantProfile(
        tenantId: tenantId,
        primaryColorHex: color.isEmpty ? current.primaryColorHex : color,
        profile: profile,
      );

      // Optional: refresh HQ tenants list cache
      _ref.invalidate(hqTenantsProvider);

      state = state.copyWith(savingProfile: false, error: null);
      return true;
    } catch (e) {
      state = state.copyWith(savingProfile: false, error: e.toString());
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // Web assets (favicon / icons)
  // ─────────────────────────────────────────────

  /// Upload favicon/icons and persist a web-safe HTTPS download URL into assets.logos.
  /// Also bumps assets.version for cache busting.
  /// Upload favicon/icons and persist a web-safe HTTPS download URL into assets.logos.
  /// Also bumps assets.version.
  Future<bool> uploadWebAsset({
    required String tenantId,
    required TenantWebAssetType type,
    required Uint8List bytes,
  }) async {
    state = state.copyWith(uploadingAsset: true, error: null);
    try {
      final storage = TenantStorageService();

      // 1) Upload bytes to storage path:
      // public/{tenantId}/branding/web/{file}.png
      await storage.uploadWebAssetBytes(
        tenantId: tenantId,
        type: type,
        bytes: bytes,
      );

      // 2) Get a web-safe download URL.
      final url = await storage.getWebAssetDownloadUrl(
        tenantId: tenantId,
        type: type,
      );

      if (url == null || url.trim().isEmpty) {
        throw StateError('Upload succeeded but download URL was null/empty');
      }

      // 3) Persist into tenant assets.logos + bump version.
      final svc = await _svc();
      await svc.updateTenantWebAsset(
        tenantId: tenantId,
        assetKey: _assetKeyFor(type),
        downloadUrl: url,
      );

      _ref.invalidate(hqTenantsProvider);

      state = state.copyWith(uploadingAsset: false, error: null);
      return true;
    } catch (e) {
      state = state.copyWith(uploadingAsset: false, error: e.toString());
      return false;
    }
  }

  /// Delete storage object and remove it from assets.logos. Also bumps version.
  Future<bool> deleteWebAsset({
    required String tenantId,
    required TenantWebAssetType type,
  }) async {
    state = state.copyWith(uploadingAsset: true, error: null);
    try {
      final storage = TenantStorageService();
      await storage.deleteWebAsset(tenantId: tenantId, type: type);

      final svc = await _svc();
      final current = await svc.getTenantProfile(tenantId);

      final key = _assetKeyFor(type);

      // Remove the key from logos (if present) and bump version.
      final newLogos = Map<String, String>.from(current.assets.logos);
      newLogos.remove(key);

      await svc.updateTenantProfile(
        tenantId: tenantId,
        assets: <String, dynamic>{
          'bucket': current.assets.bucket,
          'version': current.assets.version + 1,
          'logos': newLogos,
        },
      );

      _ref.invalidate(hqTenantsProvider);

      state = state.copyWith(uploadingAsset: false, error: null);
      return true;
    } catch (e) {
      state = state.copyWith(uploadingAsset: false, error: e.toString());
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  static String _assetKeyFor(TenantWebAssetType type) {
    switch (type) {
      case TenantWebAssetType.favicon:
        return 'favicon';
      case TenantWebAssetType.icon192:
        return 'icon192';
      case TenantWebAssetType.icon512:
        return 'icon512';
      case TenantWebAssetType.maskableIcon192:
        return 'maskableIcon192';
      case TenantWebAssetType.maskableIcon512:
        return 'maskableIcon512';
    }
  }
}
