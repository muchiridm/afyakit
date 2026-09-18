// lib/features/hq/apps/controllers/app_profile_controller.dart

import 'package:afyakit/features/hq/apps/controllers/app_profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

      ref.listen<AppProfileEditorInput?>(appProfileEditorInputProvider, (
        previous,
        next,
      ) {
        controller.loadInitial(next);
      }, fireImmediately: true);

      return controller;
    }, dependencies: <ProviderOrFamily>[appProfileEditorInputProvider]);

class AppProfileController extends StateNotifier<AppProfileState> {
  AppProfileController(this.ref) : super(const AppProfileState()) {
    _ensureControllers();
  }

  final Ref ref;

  TextEditingController? _appId;
  TextEditingController? _displayName;
  TextEditingController? _website;
  TextEditingController? _email;
  TextEditingController? _supportNote;

  bool _controllersReady = false;
  String? _loadedKey;

  TextEditingController get appId => _appId!;

  TextEditingController get displayName => _displayName!;

  TextEditingController get website => _website!;

  TextEditingController get email => _email!;

  TextEditingController get supportNote => _supportNote!;

  void _ensureControllers() {
    if (_controllersReady) return;

    _appId = TextEditingController();
    _displayName = TextEditingController();
    _website = TextEditingController();
    _email = TextEditingController();
    _supportNote = TextEditingController();

    _controllersReady = true;
  }

  void loadInitial(AppProfileEditorInput? input) {
    if (input == null) return;

    final tenant = input.tenant;
    final initial = input.initial;

    final key = '${tenant.id}:${initial?.id ?? '<create>'}';

    if (_loadedKey == key) {
      return;
    }

    _loadedKey = key;

    appId.text = initial?.id ?? '';

    displayName.text = initial?.displayName ?? '';

    website.text = initial?.details.website ?? '';

    email.text = initial?.details.email ?? '';

    supportNote.text = initial?.details.supportNote ?? '';

    final existing = initial?.features.values ?? const <String, bool>{};

    /*
     * Preserve existing keys, but ensure every registered app-capable
     * feature has an explicit value.
     *
     * HQ itself is not a tenant sub-app capability.
     */
    final features = <String, bool>{
      ...existing,
      for (final definition in FeatureRegistry.features)
        if (definition.key != FeatureKeys.hq)
          definition.key: existing[definition.key] == true,
    };

    state = state.copyWith(
      tenant: tenant,
      initial: initial,
      active: initial?.active ?? true,
      features: features,
      error: null,
    );
  }

  bool tenantAllows(String featureKey) {
    final tenant = state.tenant;

    if (tenant == null) {
      return false;
    }

    if (featureKey == FeatureKeys.hq) {
      return false;
    }

    return tenant.features.enabled(featureKey);
  }

  void setFeature(String key, bool enabled) {
    if (enabled && !tenantAllows(key)) {
      return;
    }

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

    if (tenant == null) {
      return const <String, bool>{};
    }

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

  Future<bool> save() async {
    final tenant = state.tenant;

    if (tenant == null) {
      state = state.copyWith(error: 'Missing parent tenant');
      return false;
    }

    final service = await ref.read(appProfileServiceProvider.future);

    final name = displayName.text.trim();

    if (name.isEmpty) {
      state = state.copyWith(error: 'Display name is required');
      return false;
    }

    state = state.copyWith(busy: true, error: null);

    try {
      final features = buildFeaturesPayload();

      if (state.isCreate) {
        final id = _normalizeAppId(appId.text);

        if (id.isEmpty) {
          state = state.copyWith(busy: false, error: 'App ID is required');

          return false;
        }

        await service.createAppProfile(
          tenantId: tenant.id,
          appId: id,
          displayName: name,
          features: features,
          profile: <String, dynamic>{
            'website': website.text.trim(),
            'email': email.text.trim(),
            'supportNote': supportNote.text.trim(),
          },
          active: state.active,
        );
      } else {
        final initial = state.initial!;

        /*
         * Fetch latest app first so editing organisation/contact fields
         * cannot accidentally wipe branding/SEO written elsewhere.
         */
        final current = await service.getAppProfile(
          tenantId: tenant.id,
          appId: initial.id,
        );

        await service.updateAppProfile(
          tenantId: tenant.id,
          appId: initial.id,
          displayName: name,
          features: features,
          active: state.active,
          profile: <String, dynamic>{
            'tagline': current.details.tagline,
            'website': website.text.trim(),
            'email': email.text.trim(),
            'supportNote': supportNote.text.trim(),
            'seoTitle': current.details.seoTitle,
            'seoDescription': current.details.seoDescription,
          },
        );
      }

      ref.invalidate(hqAppProfilesProvider(tenant.id));

      state = state.copyWith(busy: false, error: null);

      return true;
    } catch (error) {
      state = state.copyWith(busy: false, error: '$error');

      return false;
    }
  }

  Future<bool> delete() async {
    final tenant = state.tenant;

    final initial = state.initial;

    if (tenant == null || initial == null) {
      state = state.copyWith(error: 'Cannot delete app: missing context');

      return false;
    }

    final service = await ref.read(appProfileServiceProvider.future);

    state = state.copyWith(busy: true, error: null);

    try {
      await service.deleteAppProfile(tenantId: tenant.id, appId: initial.id);

      ref.invalidate(hqAppProfilesProvider(tenant.id));

      state = state.copyWith(busy: false, error: null);

      return true;
    } catch (error) {
      state = state.copyWith(busy: false, error: '$error');

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
    _appId?.dispose();
    _displayName?.dispose();
    _website?.dispose();
    _email?.dispose();
    _supportNote?.dispose();

    super.dispose();
  }
}
