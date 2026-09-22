// lib/features/hq/apps/controllers/app_profile_controller.dart

import 'package:afyakit/app/models/app_profile.dart';
import 'package:afyakit/core/tenancy/models/tenant_profile.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/models/app_details.dart';
import 'package:afyakit/core/capabilities/feature_keys.dart';
import 'package:afyakit/core/capabilities/feature_registry.dart';

import 'package:afyakit/features/hq/apps/providers/hq_app_profiles_provider.dart';
import 'package:afyakit/features/hq/apps/services/app_profile_service.dart';

final appProfileEditorInputProvider = Provider<AppProfileEditorInput?>(
  (ref) => null,
);

final appProfileControllerProvider =
    AutoDisposeStateNotifierProvider<AppProfileController, AppProfileState>((
      ref,
    ) {
      final controller = AppProfileController(ref);

      ref.listen<AppProfileEditorInput?>(
        appProfileEditorInputProvider,
        (_, next) => controller.loadInitial(next),
        fireImmediately: true,
      );

      return controller;
    }, dependencies: <ProviderOrFamily>[appProfileEditorInputProvider]);

class AppProfileController extends StateNotifier<AppProfileState> {
  AppProfileController(this.ref) : super(const AppProfileState());

  final Ref ref;

  // App identity
  final appId = TextEditingController();
  final displayName = TextEditingController();

  // Public profile
  final tagline = TextEditingController();
  final website = TextEditingController();
  final email = TextEditingController();
  final whatsapp = TextEditingController();
  final supportNote = TextEditingController();

  // Payments
  final mobileMoneyName = TextEditingController();
  final mobileMoneyNumber = TextEditingController();
  final mobileMoneyAccount = TextEditingController();

  // Compliance
  final registrationNumber = TextEditingController();

  // SEO
  final seoTitle = TextEditingController();
  final seoDescription = TextEditingController();

  String? _loadedKey;

  void loadInitial(AppProfileEditorInput? input) {
    if (input == null) return;

    final tenant = input.tenant;
    final initial = input.initial;
    final key = '${tenant.id}:${initial?.id ?? '<create>'}';

    if (_loadedKey == key) return;
    _loadedKey = key;

    appId.text = initial?.id ?? '';
    displayName.text = initial?.displayName ?? '';

    _loadDetails(initial?.details ?? const AppDetails());

    final existing = initial?.features.values ?? const <String, bool>{};

    state = state.copyWith(
      tenant: tenant,
      initial: initial,
      active: initial?.active ?? true,
      features: <String, bool>{
        ...existing,
        for (final feature in FeatureRegistry.features)
          if (feature.key != FeatureKeys.hq)
            feature.key: existing[feature.key] == true,
      },
      error: null,
    );
  }

  void _loadDetails(AppDetails details) {
    tagline.text = details.tagline ?? '';
    website.text = details.website ?? '';
    email.text = details.email ?? '';
    whatsapp.text = details.whatsapp ?? '';
    supportNote.text = details.supportNote ?? '';

    mobileMoneyName.text = details.mobileMoneyName ?? '';
    mobileMoneyNumber.text = details.mobileMoneyNumber ?? '';
    mobileMoneyAccount.text = details.mobileMoneyAccount ?? '';

    registrationNumber.text = details.registrationNumber ?? '';

    seoTitle.text = details.seoTitle ?? '';
    seoDescription.text = details.seoDescription ?? '';
  }

  bool tenantAllows(String featureKey) {
    final tenant = state.tenant;

    return tenant != null &&
        featureKey != FeatureKeys.hq &&
        tenant.features.enabled(featureKey);
  }

  void setFeature(String key, bool enabled) {
    if (enabled && !tenantAllows(key)) return;

    state = state.copyWith(
      features: {...state.features, key: enabled},
      error: null,
    );
  }

  void setActive(bool value) {
    state = state.copyWith(active: value, error: null);
  }

  Map<String, bool> buildFeaturesPayload() {
    final tenant = state.tenant;

    if (tenant == null) return const <String, bool>{};

    final keys = <String>{
      ...state.features.keys,
      ...tenant.features.values.keys,
    };

    return <String, bool>{
      for (final key in keys)
        key:
            key != FeatureKeys.hq &&
            tenant.has(key) &&
            state.features[key] == true,
    };
  }

  // Profile owns business/operational information.
  // Branding owns primaryColorHex and assets.
  Map<String, dynamic> _buildProfile(AppDetails current) {
    return <String, dynamic>{
      ...current.toMap(),

      'tagline': tagline.text.trim(),
      'website': website.text.trim(),
      'email': email.text.trim(),
      'whatsapp': whatsapp.text.trim(),
      'supportNote': supportNote.text.trim(),

      'seoTitle': seoTitle.text.trim(),
      'seoDescription': seoDescription.text.trim(),

      'payments': <String, dynamic>{
        ...current.payments,
        'mobileMoneyName': mobileMoneyName.text.trim(),
        'mobileMoneyNumber': mobileMoneyNumber.text.trim(),
        'mobileMoneyAccount': mobileMoneyAccount.text.trim(),
      },

      'compliance': <String, dynamic>{
        ...current.compliance,
        'registrationNumber': registrationNumber.text.trim(),
      },
    };
  }

  Future<bool> save() async {
    final tenant = state.tenant;

    if (tenant == null) {
      state = state.copyWith(error: 'Missing parent tenant');
      return false;
    }

    if (state.busy) return false;

    final name = displayName.text.trim();

    if (name.isEmpty) {
      state = state.copyWith(error: 'Display name is required');
      return false;
    }

    state = state.copyWith(busy: true, error: null);

    try {
      final service = await ref.read(appProfileServiceProvider.future);
      final features = buildFeaturesPayload();

      late final String id;
      late final Map<String, dynamic> submittedProfile;

      if (state.isCreate) {
        id = _normalizeAppId(appId.text);

        if (id.isEmpty) {
          throw StateError('App ID is required');
        }

        submittedProfile = _buildProfile(const AppDetails());

        await service.createAppProfile(
          tenantId: tenant.id,
          appId: id,
          displayName: name,
          features: features,
          profile: submittedProfile,
          active: state.active,
        );
      } else {
        id = state.initial!.id;

        // Read latest details through the HQ API
        // before building the update payload.
        final current = await service.getAppProfile(
          tenantId: tenant.id,
          appId: id,
        );

        submittedProfile = _buildProfile(current.details);

        await service.updateAppProfile(
          tenantId: tenant.id,
          appId: id,
          displayName: name,
          features: features,
          active: state.active,
          profile: submittedProfile,
        );
      }

      // Verify the backend actually persisted
      // the fields we just submitted.
      final saved = await service.getAppProfile(tenantId: tenant.id, appId: id);

      final expected = AppDetails.fromMap(submittedProfile);

      if (!_detailsMatch(expected, saved.details)) {
        throw StateError(
          'The backend accepted the save, but the '
          'reloaded app profile does not contain all '
          'submitted details. Check the HQ API '
          'profile PATCH/CREATE handler and response.',
        );
      }

      ref.invalidate(hqAppProfilesProvider(tenant.id));

      state = state.copyWith(busy: false, error: null);
      return true;
    } catch (error) {
      state = state.copyWith(busy: false, error: error.toString());
      return false;
    }
  }

  bool _detailsMatch(AppDetails expected, AppDetails actual) {
    String clean(String? value) => value?.trim() ?? '';

    return clean(expected.tagline) == clean(actual.tagline) &&
        clean(expected.website) == clean(actual.website) &&
        clean(expected.email) == clean(actual.email) &&
        clean(expected.whatsapp) == clean(actual.whatsapp) &&
        clean(expected.supportNote) == clean(actual.supportNote) &&
        clean(expected.seoTitle) == clean(actual.seoTitle) &&
        clean(expected.seoDescription) == clean(actual.seoDescription) &&
        clean(expected.mobileMoneyName) == clean(actual.mobileMoneyName) &&
        clean(expected.mobileMoneyNumber) == clean(actual.mobileMoneyNumber) &&
        clean(expected.mobileMoneyAccount) ==
            clean(actual.mobileMoneyAccount) &&
        clean(expected.registrationNumber) == clean(actual.registrationNumber);
  }

  Future<bool> delete() async {
    final tenant = state.tenant;
    final initial = state.initial;

    if (tenant == null || initial == null) {
      state = state.copyWith(error: 'Cannot delete app: missing context');
      return false;
    }

    if (state.busy) return false;

    state = state.copyWith(busy: true, error: null);

    try {
      final service = await ref.read(appProfileServiceProvider.future);

      await service.deleteAppProfile(tenantId: tenant.id, appId: initial.id);

      ref.invalidate(hqAppProfilesProvider(tenant.id));

      state = state.copyWith(busy: false, error: null);
      return true;
    } catch (error) {
      state = state.copyWith(busy: false, error: error.toString());
      return false;
    }
  }

  String _normalizeAppId(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      appId,
      displayName,
      tagline,
      website,
      email,
      whatsapp,
      supportNote,
      mobileMoneyName,
      mobileMoneyNumber,
      mobileMoneyAccount,
      registrationNumber,
      seoTitle,
      seoDescription,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }
}

@immutable
class AppProfileEditorInput {
  const AppProfileEditorInput({required this.tenant, this.initial});

  final TenantProfile tenant;
  final AppProfile? initial;
}

@immutable
class AppProfileState {
  const AppProfileState({
    this.busy = false,
    this.error,
    this.tenant,
    this.initial,
    this.active = true,
    this.features = const <String, bool>{},
  });

  final bool busy;
  final String? error;

  final TenantProfile? tenant;
  final AppProfile? initial;

  final bool active;

  /// App feature exposure.
  ///
  /// Must remain a subset of tenant.features.
  final Map<String, bool> features;

  static const Object _unset = Object();

  bool get isCreate => initial == null;

  AppProfileState copyWith({
    bool? busy,
    Object? error = _unset,
    Object? tenant = _unset,
    Object? initial = _unset,
    bool? active,
    Map<String, bool>? features,
  }) {
    return AppProfileState(
      busy: busy ?? this.busy,
      error: error == _unset ? this.error : error as String?,
      tenant: tenant == _unset ? this.tenant : tenant as TenantProfile?,
      initial: initial == _unset ? this.initial : initial as AppProfile?,
      active: active ?? this.active,
      features: features ?? this.features,
    );
  }
}
