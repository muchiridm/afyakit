import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/tenancy/models/feature_keys.dart';
import 'package:afyakit/core/tenancy/models/feature_registry.dart';
import 'package:afyakit/core/tenancy/providers/tenant_profile_providers.dart';

/// Single truth:
/// TenantProfile.features is a map of { moduleKey: bool } (root modules only).
final isFeatureEnabledProvider = Provider.autoDispose.family<bool, String>((
  ref,
  key,
) {
  final k = key.trim();
  if (k.isEmpty) return false;

  final profileAsync = ref.watch(tenantProfileProvider);
  return profileAsync.maybeWhen(data: (p) => p.has(k), orElse: () => false);
});

/// Alias: module == feature (since we only do root modules right now)
final isModuleEnabledProvider = Provider.autoDispose.family<bool, String>((
  ref,
  moduleKey,
) {
  return ref.watch(isFeatureEnabledProvider(moduleKey));
});

/// Convenience booleans used in shells (optional, but nice).
final tenantHqEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isModuleEnabledProvider(FeatureKeys.hq));
});

final tenantInventoryEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isModuleEnabledProvider(FeatureKeys.inventory));
});

final tenantRetailEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isModuleEnabledProvider(FeatureKeys.retail));
});

final tenantDispensingEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isModuleEnabledProvider(FeatureKeys.dispensing));
});

final tenantLabsEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isModuleEnabledProvider(FeatureKeys.labs));
});

final tenantConsultationEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isModuleEnabledProvider(FeatureKeys.consultation));
});

final tenantRiderEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isModuleEnabledProvider(FeatureKeys.rider));
});

/// Handy for HQ editor: list all modules from the registry.
final allModuleDefsProvider = Provider.autoDispose<List<ModuleDef>>((ref) {
  return FeatureRegistry.modules;
});

/// ✅ Staff can toggle into "member view" only if tenant has any member UX enabled.
/// Keep this explicit and boring; expand as you add member-facing modules.
final tenantMemberUxEnabledProvider = Provider.autoDispose<bool>((ref) {
  final retail = ref.watch(tenantRetailEnabledProvider);

  // later:
  // final consultation = ref.watch(tenantConsultationEnabledProvider);
  // final labs = ref.watch(tenantLabsEnabledProvider);

  return retail;
});
