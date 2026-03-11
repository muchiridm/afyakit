// lib/core/hq/tenants/controllers/tenant_profile_controller.dart

import 'package:afyakit/core/hq/tenants/controllers/tenant_profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/hq/tenants/extensions/tenant_status_x.dart';
import 'package:afyakit/core/hq/tenants/models/feature_registry.dart';
import 'package:afyakit/core/hq/tenants/models/tenant_profile.dart';
import 'package:afyakit/core/hq/tenants/services/tenant_service.dart';

// ✅ Replace old stream invalidation with your new fetch provider.
import 'package:afyakit/core/hq/tenants/providers/hq_tenants_provider.dart';

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
    >(
      (ref) {
        final controller = TenantProfileController(ref);

        // ✅ Smart part lives here, not in the widget.
        ref.listen<TenantProfile?>(
          tenantProfileEditorInputProvider,
          (prev, next) => controller.loadInitial(next),
          fireImmediately: true,
        );

        return controller;
      },

      // ✅ keep dependency for override correctness
      dependencies: <ProviderOrFamily>[tenantProfileEditorInputProvider],
    );

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

  /// ✅ New: account numbering format (no prefix/pad)
  /// Default: "yymm_seq4" (26020001)
  TextEditingController? _accountFormat;

  bool _controllersReady = false;
  String? _loadedTenantId; // prevents pointless re-load loops

  TextEditingController get displayName => _displayName!;
  TextEditingController get website => _website!;
  TextEditingController get email => _email!;
  TextEditingController get whatsapp => _whatsapp!;
  TextEditingController get registrationNumber => _registrationNumber!;

  TextEditingController get mmName => _mmName!;
  TextEditingController get mmAccount => _mmAccount!;
  TextEditingController get mmNumber => _mmNumber!;

  TextEditingController get accountFormat => _accountFormat!;

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

    _accountFormat = TextEditingController();

    _controllersReady = true;
  }

  void _fillControllersFrom(TenantProfile? p) {
    _ensureControllers();

    final payments = p?.details.payments ?? const <String, dynamic>{};
    final compliance = p?.details.compliance ?? const <String, dynamic>{};

    displayName.text = p?.displayName ?? '';
    website.text = p?.details.website ?? '';
    email.text = p?.details.email ?? '';
    whatsapp.text = p?.details.whatsapp ?? '';

    // ✅ keep only the canonical key going forward
    registrationNumber.text =
        (compliance['registrationNumber'] as String?)?.trim() ?? '';

    mmName.text = (payments['mobileMoneyName'] as String?)?.trim() ?? '';
    mmAccount.text = (payments['mobileMoneyAccount'] as String?)?.trim() ?? '';
    mmNumber.text = (payments['mobileMoneyNumber'] as String?)?.trim() ?? '';

    // ✅ account format (no more prefix/pad)
    final fmt = (p?.details.accountFormat ?? '').trim();
    accountFormat.text = fmt.isNotEmpty ? fmt : 'yymm_seq4';
  }

  /// Builds the "profile" map payload written under tenant.profile (or wherever svc uses it).
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

    final fmt = accountFormat.text.trim();
    final out = <String, dynamic>{
      'website': website.text.trim(),
      'email': email.text.trim(),
      'whatsapp': whatsapp.text.trim(),
      'currency': state.currency,
      'accountFormat': fmt.isNotEmpty ? fmt : 'yymm_seq4',
      if (compliance.isNotEmpty) 'compliance': compliance,
      if (payments.isNotEmpty) 'payments': payments,
    };

    return out;
  }

  // ───────────────────────── Public init / reset ─────────────────────────

  /// Safe to call multiple times. No-ops on same tenantId.
  void loadInitial(TenantProfile? initial) {
    final tenantId = initial?.id;

    // If we already loaded this exact tenant into the form, no-op.
    if (_loadedTenantId == tenantId && state.initial?.id == tenantId) return;
    _loadedTenantId = tenantId;

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
    _loadedTenantId = null;
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

  Map<String, bool> buildFeaturesPayload() {
    return <String, bool>{
      for (final e in state.features.entries) e.key: e.value == true,
    };
  }

  // ───────────────────────── Save / delete ─────────────────────────

  Future<bool> save({Map<String, dynamic>? assets}) async {
    final svc = await ref.read(tenantServiceProvider.future);

    state = state.copyWith(busy: true, error: null);
    try {
      final tenantId = state.initial?.id;
      final name = displayName.text.trim();

      if (name.isEmpty) {
        state = state.copyWith(busy: false, error: 'Display name is required');
        return false;
      }

      final profile = buildProfilePayload();
      final features = buildFeaturesPayload();

      if (tenantId == null || tenantId.trim().isEmpty) {
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
          tenantId: tenantId,
          displayName: name,
          primaryColorHex: state.primaryColorHex,
          features: features,
          profile: profile,
          assets: assets,
          status: state.status,
        );
      }

      // ✅ New invalidation target (no streams)
      ref.invalidate(hqTenantsProvider);

      state = state.copyWith(busy: false, error: null);
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: '$e');
      return false;
    }
  }

  Future<bool> delete({bool hard = true}) async {
    final svc = await ref.read(tenantServiceProvider.future);

    final tenantId = state.initial?.id;
    if (tenantId == null || tenantId.trim().isEmpty) {
      state = state.copyWith(error: 'Cannot delete: missing tenant id');
      return false;
    }

    state = state.copyWith(busy: true, error: null);
    try {
      await svc.deleteTenantProfile(tenantId, hard: hard);

      // ✅ New invalidation target (no streams)
      ref.invalidate(hqTenantsProvider);

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

    _accountFormat?.dispose();

    super.dispose();
  }
}
