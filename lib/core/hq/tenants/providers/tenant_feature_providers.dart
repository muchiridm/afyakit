// lib/core/hq/tenants/providers/tenant_feature_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/hq/tenants/models/feature_keys.dart';
import 'package:afyakit/core/hq/tenants/models/feature_registry.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_profile_providers.dart';

final isFeatureEnabledProvider = Provider.autoDispose.family<bool, String>((
  ref,
  key,
) {
  final k = key.trim();
  if (k.isEmpty) return false;

  final profileAsync = ref.watch(tenantProfileProvider);

  return profileAsync.when(
    loading: () => true,
    error: (_, __) => false,
    data: (p) => p.has(k),
  );
});

final isModuleEnabledProvider = Provider.autoDispose.family<bool, String>((
  ref,
  moduleKey,
) {
  return ref.watch(isFeatureEnabledProvider(moduleKey));
});

final tenantHqEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isModuleEnabledProvider(FeatureKeys.hq));
});

final tenantInventoryEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isModuleEnabledProvider(FeatureKeys.inventory));
});

final tenantRetailEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isModuleEnabledProvider(FeatureKeys.retail));
});

final tenantClinicalEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isModuleEnabledProvider(FeatureKeys.clinical));
});

final tenantRiderEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isModuleEnabledProvider(FeatureKeys.rider));
});

final tenantReportingEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isModuleEnabledProvider(FeatureKeys.reporting));
});

final tenantMessagingEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isModuleEnabledProvider(FeatureKeys.messaging));
});

final tenantBackupEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isModuleEnabledProvider(FeatureKeys.backup));
});

final allModuleDefsProvider = Provider.autoDispose<List<FeatureDef>>((ref) {
  return FeatureRegistry.features;
});

final tenantMemberUxEnabledProvider = Provider.autoDispose<bool>((ref) {
  final retail = ref.watch(tenantRetailEnabledProvider);
  final clinical = ref.watch(tenantClinicalEnabledProvider);
  return retail || clinical;
});
