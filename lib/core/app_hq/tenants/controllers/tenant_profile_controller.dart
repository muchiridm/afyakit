// lib/core/app_hq/tenants/controllers/tenant_profile_controller.dart

import 'package:afyakit/core/app_hq/tenants/controllers/tenant_profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/app_hq/tenants/providers/tenant_profiles_stream_provider.dart';
import 'package:afyakit/core/app_hq/tenants/services/tenant_admin_service.dart';

import 'package:afyakit/core/tenancy/extensions/tenant_status_x.dart';
import 'package:afyakit/core/tenancy/models/feature_registry.dart';
import 'package:afyakit/core/tenancy/models/tenant_profile.dart';

/// ─────────────────────────────────────────────
/// Editor input (drives the controller)
/// ─────────────────────────────────────────────
/// Set this from the parent (route/screen) that knows which tenant is being edited.
/// - null => create mode
/// - non-null => edit mode
final tenantProfileEditorInputProvider = Provider<TenantProfile?>(
  (ref) => null,
);

/// ─────────────────────────────────────────────
/// Provider (smart: reacts to input changes)
/// ─────────────────────────────────────────────
final tenantProfileControllerProvider =
    AutoDisposeStateNotifierProvider<
      TenantProfileController,
      TenantProfileState
    >((ref) {
      final controller = TenantProfileController(ref);

      // ✅ Smart part lives here, not in the widget.
      ref.listen<TenantProfile?>(tenantProfileEditorInputProvider, (
        prev,
        next,
      ) {
        controller.loadInitial(next);
      }, fireImmediately: true);

      return controller;
    });

/// ─────────────────────────────────────────────
/// Controller
/// ─────────────────────────────────────────────
class TenantProfileController extends StateNotifier<TenantProfileState> {
  TenantProfileController(this.ref) : super(const TenantProfileState()) {
    _ensureControllers();
  }

  final Ref ref;

  // ───────────────────────── Controllers (created once) ─────────────────────────

  TextEditingController? _displayName;
  TextEditingController? _website;
  TextEditingController? _email;
  TextEditingController? _whatsapp;
  TextEditingController? _registrationNumber;

  TextEditingController? _mmName;
  TextEditingController? _mmAccount;
  TextEditingController? _mmNumber;

  TextEditingController? _accountPrefix;
  TextEditingController? _accountPad;

  bool _controllersReady = false;
  String? _loadedSlug; // prevents pointless re-load loops

  TextEditingController get displayName => _displayName!;
  TextEditingController get website => _website!;
  TextEditingController get email => _email!;
  TextEditingController get whatsapp => _whatsapp!;
  TextEditingController get registrationNumber => _registrationNumber!;

  TextEditingController get mmName => _mmName!;
  TextEditingController get mmAccount => _mmAccount!;
  TextEditingController get mmNumber => _mmNumber!;

  TextEditingController get accountPrefix => _accountPrefix!;
  TextEditingController get accountPad => _accountPad!;

  void _ensureControllers() {
    if (_controllersReady) return;

    _displayName = TextEditingController();
    _website = TextEditingController();
    _email = TextEditingController();
    _whatsapp = TextEditingController();
    _registrationNumber = TextEditingController();

    _mmName = TextEditingController();
    _mmAccount = TextEditingController();
    _mmNumber = TextEditingController();

    _accountPrefix = TextEditingController();
    _accountPad = TextEditingController();

    _controllersReady = true;
  }

  void _fillControllersFrom(TenantProfile? p) {
    _ensureControllers();

    final payments = p?.details.payments ?? const <String, dynamic>{};

    displayName.text = p?.displayName ?? '';
    website.text = p?.details.website ?? '';
    email.text = p?.details.email ?? '';
    whatsapp.text = p?.details.whatsapp ?? '';

    registrationNumber.text =
        (p?.details.compliance['registrationNumber'] as String?) ??
        (p?.details.compliance['regNumber'] as String?) ??
        '';

    mmName.text = payments['mobileMoneyName'] as String? ?? '';
    mmAccount.text = payments['mobileMoneyAccount'] as String? ?? '';
    mmNumber.text = payments['mobileMoneyNumber'] as String? ?? '';

    accountPrefix.text = (p?.details.accountPrefix ?? 'DP').toUpperCase();
    accountPad.text = '${p?.details.accountPad ?? 6}';
  }

  // ───────────────────────── Public init / reset ─────────────────────────

  /// Safe to call multiple times. No-ops on same slug.
  void loadInitial(TenantProfile? initial) {
    final slug = initial?.id;

    // If we already loaded this exact tenant into the form, no-op.
    if (_loadedSlug == slug && state.initial?.id == slug) return;
    _loadedSlug = slug;

    _fillControllersFrom(initial);

    final p = initial;

    final primaryColorHex = p?.primaryColorHex ?? '#2196F3';
    final currency = p?.details.currency ?? 'KES';
    final status = p?.status ?? TenantStatus.active;

    final existing = p?.features.features ?? const <String, bool>{};

    // Preserve unknown keys + ensure all registry keys exist.
    final features = <String, bool>{
      ...existing.map((k, v) => MapEntry(k, v == true)),
      for (final k in FeatureRegistry.keys) k: existing[k] == true,
    };

    state = state.copyWith(
      initial: initial,
      primaryColorHex: primaryColorHex,
      currency: currency,
      status: status,
      features: features,
      error: null,
    );
  }

  /// Convenience: reset the editor back to create-mode defaults.
  void resetToCreate() {
    _loadedSlug = null;
    loadInitial(null);
  }

  // ───────────────────────── State setters ─────────────────────────

  void setPrimaryColorHex(String v) =>
      state = state.copyWith(primaryColorHex: v.trim(), error: null);

  void setCurrency(String v) =>
      state = state.copyWith(currency: v.trim(), error: null);

  void setStatus(TenantStatus s) =>
      state = state.copyWith(status: s, error: null);

  void setFeature(String key, bool value) {
    state = state.copyWith(
      features: {...state.features, key: value == true},
      error: null,
    );
  }

  void toggleShowUnknown() =>
      state = state.copyWith(showUnknown: !state.showUnknown);

  // ───────────────────────── Payload builders ─────────────────────────

  Map<String, dynamic> buildProfilePayload() {
    final compliance = <String, dynamic>{};
    final reg = registrationNumber.text.trim();
    if (reg.isNotEmpty) compliance['registrationNumber'] = reg;

    final payments = <String, dynamic>{};
    final mName = mmName.text.trim();
    final mAcc = mmAccount.text.trim();
    final mNum = mmNumber.text.trim();

    if (mName.isNotEmpty) payments['mobileMoneyName'] = mName;
    if (mAcc.isNotEmpty) payments['mobileMoneyAccount'] = mAcc;
    if (mNum.isNotEmpty) payments['mobileMoneyNumber'] = mNum;

    // Account numbering policy
    final prefixRaw = accountPrefix.text.trim().toUpperCase();
    final prefix = prefixRaw.isEmpty ? 'DP' : prefixRaw;

    final padRaw = accountPad.text.trim();
    final padParsed = int.tryParse(padRaw) ?? 6;
    final pad = padParsed.clamp(3, 10);

    return <String, dynamic>{
      'website': website.text.trim(),
      'email': email.text.trim(),
      'whatsapp': whatsapp.text.trim(),
      'currency': state.currency,
      'accountPrefix': prefix,
      'accountPad': pad,
      if (compliance.isNotEmpty) 'compliance': compliance,
      if (payments.isNotEmpty) 'payments': payments,
    };
  }

  Map<String, bool> buildFeaturesPayload() {
    return <String, bool>{
      for (final e in state.features.entries) e.key: e.value == true,
    };
  }

  // ───────────────────────── Save / delete ─────────────────────────

  Future<bool> save({Map<String, dynamic>? assets}) async {
    final svc = await ref.read(tenantAdminServiceProvider.future);

    state = state.copyWith(busy: true, error: null);
    try {
      final slug = state.initial?.id;
      final name = displayName.text.trim();

      if (name.isEmpty) {
        state = state.copyWith(busy: false, error: 'Display name is required');
        return false;
      }

      final profile = buildProfilePayload();
      final features = buildFeaturesPayload();

      if (slug == null || slug.trim().isEmpty) {
        await svc.createTenantProfile(
          displayName: name,
          primaryColorHex: state.primaryColorHex,
          features: features,
          profile: profile,
          assets: assets ?? const {},
          status: state.status,
        );
      } else {
        await svc.updateTenantProfile(
          slug: slug,
          displayName: name,
          primaryColorHex: state.primaryColorHex,
          features: features,
          profile: profile,
          assets: assets,
          status: state.status,
        );
      }

      ref.invalidate(tenantProfilesStreamProvider);

      state = state.copyWith(busy: false, error: null);
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: '$e');
      return false;
    }
  }

  Future<bool> delete({bool hard = true}) async {
    final svc = await ref.read(tenantAdminServiceProvider.future);

    final slug = state.initial?.id;
    if (slug == null || slug.trim().isEmpty) {
      state = state.copyWith(error: 'Cannot delete: missing tenant id');
      return false;
    }

    state = state.copyWith(busy: true, error: null);
    try {
      await svc.deleteTenantProfile(slug, hard: hard);

      ref.invalidate(tenantProfilesStreamProvider);

      state = state.copyWith(busy: false, error: null);
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: '$e');
      return false;
    }
  }

  // ───────────────────────── Dispose ─────────────────────────

  @override
  void dispose() {
    _displayName?.dispose();
    _website?.dispose();
    _email?.dispose();
    _whatsapp?.dispose();
    _registrationNumber?.dispose();

    _mmName?.dispose();
    _mmAccount?.dispose();
    _mmNumber?.dispose();

    _accountPrefix?.dispose();
    _accountPad?.dispose();

    super.dispose();
  }
}
