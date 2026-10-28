// lib/features/hq/tenants/controllers/tenant_profile_controller.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/capabilities/feature_registry.dart';
import 'package:afyakit/core/tenancy/models/tenant_profile.dart';
import 'package:afyakit/core/tenancy/models/tenant_status_x.dart';
import 'package:afyakit/features/hq/tenants/controllers/tenant_profile_state.dart';
import 'package:afyakit/features/hq/tenants/providers/hq_tenants_provider.dart';
import 'package:afyakit/features/hq/tenants/services/tenant_service.dart';

final tenantProfileEditorInputProvider = Provider<TenantProfile?>(
  (ref) => null,
);

final tenantProfileControllerProvider =
    AutoDisposeStateNotifierProvider<
      TenantProfileController,
      TenantProfileState
    >((ref) {
      final controller = TenantProfileController(ref);

      ref.listen<TenantProfile?>(tenantProfileEditorInputProvider, (
        previous,
        next,
      ) {
        controller.loadInitial(next);
      }, fireImmediately: true);

      return controller;
    }, dependencies: <ProviderOrFamily>[tenantProfileEditorInputProvider]);

class TenantProfileController extends StateNotifier<TenantProfileState> {
  TenantProfileController(this.ref) : super(const TenantProfileState()) {
    _ensureController();
  }

  final Ref ref;

  TextEditingController? _tenantId;

  bool _controllerReady = false;

  String? _loadedTenantId;

  TextEditingController get tenantId => _tenantId!;

  void _ensureController() {
    if (_controllerReady) {
      return;
    }

    _tenantId = TextEditingController();

    _controllerReady = true;
  }

  void _fillControllerFrom(TenantProfile? profile) {
    _ensureController();

    tenantId.text = profile?.id ?? '';
  }

  void loadInitial(TenantProfile? initial) {
    final initialTenantId = initial?.id;

    if (_loadedTenantId == initialTenantId &&
        state.initial?.id == initialTenantId) {
      return;
    }

    _loadedTenantId = initialTenantId;

    _fillControllerFrom(initial);

    final existing = initial?.features.values ?? const <String, bool>{};

    final features = <String, bool>{
      ...existing,
      for (final key in FeatureRegistry.keys) key: existing[key] == true,
    };

    state = state.copyWith(
      initial: initial,
      status: initial?.status ?? TenantStatus.active,
      features: features,
      error: null,
    );
  }

  void resetToCreate() {
    _loadedTenantId = null;

    _fillControllerFrom(null);

    final features = <String, bool>{
      for (final key in FeatureRegistry.keys) key: false,
    };

    state = state.copyWith(
      initial: null,
      status: TenantStatus.active,
      features: features,
      error: null,
    );
  }

  void setStatus(TenantStatus status) {
    state = state.copyWith(status: status, error: null);
  }

  void setFeature(String key, bool value) {
    state = state.copyWith(
      features: {...state.features, key: value},
      error: null,
    );
  }

  Map<String, bool> buildFeaturesPayload() {
    return {for (final entry in state.features.entries) entry.key: entry.value};
  }

  Future<bool> save() async {
    final service = await ref.read(tenantServiceProvider.future);

    state = state.copyWith(busy: true, error: null);

    try {
      final existingTenantId = state.initial?.id.trim().toLowerCase();

      final enteredTenantId = tenantId.text.trim().toLowerCase();

      final features = buildFeaturesPayload();

      if (existingTenantId == null || existingTenantId.isEmpty) {
        if (enteredTenantId.isEmpty) {
          state = state.copyWith(busy: false, error: 'Tenant ID is required');

          return false;
        }

        await service.createTenantProfile(
          tenantId: enteredTenantId,
          features: features,
          status: state.status,
        );
      } else {
        await service.updateTenantProfile(
          tenantId: existingTenantId,
          features: features,
          status: state.status,
        );
      }

      ref.invalidate(hqTenantsProvider);

      state = state.copyWith(busy: false, error: null);

      return true;
    } catch (error) {
      state = state.copyWith(busy: false, error: '$error');

      return false;
    }
  }

  Future<bool> delete({bool hard = true}) async {
    final service = await ref.read(tenantServiceProvider.future);

    final currentTenantId = state.initial?.id.trim().toLowerCase();

    if (currentTenantId == null || currentTenantId.isEmpty) {
      state = state.copyWith(error: 'Cannot delete: missing tenant ID');

      return false;
    }

    state = state.copyWith(busy: true, error: null);

    try {
      await service.deleteTenantProfile(currentTenantId, hard: hard);

      ref.invalidate(hqTenantsProvider);

      state = state.copyWith(busy: false, error: null);

      return true;
    } catch (error) {
      state = state.copyWith(busy: false, error: '$error');

      return false;
    }
  }

  @override
  void dispose() {
    _tenantId?.dispose();

    super.dispose();
  }
}
