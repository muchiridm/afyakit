// lib/core/tenancy/providers/tenant_feature_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/capabilities/feature_keys.dart';
import 'package:afyakit/core/capabilities/feature_registry.dart';
import 'package:afyakit/core/tenancy/providers/tenant_profile_providers.dart';

/// Returns whether [key] is available within the current tenant's
/// capability ceiling.
///
/// This is tenant/infrastructure configuration, not current-app
/// feature exposure.
///
/// Runtime product UI should normally use:
///
///   isAppFeatureEnabledProvider(...)
///
/// instead.
final isTenantFeatureEnabledProvider = Provider.autoDispose
    .family<bool, String>((ref, key) {
      final normalizedKey = key.trim();

      if (normalizedKey.isEmpty) {
        return false;
      }

      final profileAsync = ref.watch(tenantProfileProvider);

      return profileAsync.when(
        loading: () => false,
        error: (_, __) => false,
        data: (profile) => profile.has(normalizedKey),
      );
    });

/// Alias retained for places where capabilities are conceptually
/// presented as modules.
///
/// Both this provider and [isTenantFeatureEnabledProvider] operate on
/// TenantProfile, not AppProfile.
final isTenantModuleEnabledProvider = Provider.autoDispose.family<bool, String>(
  (ref, moduleKey) {
    return ref.watch(isTenantFeatureEnabledProvider(moduleKey));
  },
);

// ─────────────────────────────────────────
// Platform
// ─────────────────────────────────────────

final tenantHqEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isTenantModuleEnabledProvider(FeatureKeys.hq));
});

final tenantBackupEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isTenantModuleEnabledProvider(FeatureKeys.backup));
});

// ─────────────────────────────────────────
// Healthcare
// ─────────────────────────────────────────

final tenantClinicalEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isTenantModuleEnabledProvider(FeatureKeys.clinical));
});

final tenantDiagnosticsEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isTenantModuleEnabledProvider(FeatureKeys.diagnostics));
});

final tenantPharmacyEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isTenantModuleEnabledProvider(FeatureKeys.pharmacy));
});

final tenantOccupationalHealthEnabledProvider = Provider.autoDispose<bool>((
  ref,
) {
  return ref.watch(
    isTenantModuleEnabledProvider(FeatureKeys.occupationalHealth),
  );
});

final tenantInsuranceEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isTenantModuleEnabledProvider(FeatureKeys.insurance));
});

// ─────────────────────────────────────────
// Commerce and operations
// ─────────────────────────────────────────

final tenantRetailEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isTenantModuleEnabledProvider(FeatureKeys.retail));
});

final tenantInventoryEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isTenantModuleEnabledProvider(FeatureKeys.inventory));
});

final tenantRiderEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isTenantModuleEnabledProvider(FeatureKeys.rider));
});

// ─────────────────────────────────────────
// Shared services
// ─────────────────────────────────────────

final tenantMessagingEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isTenantModuleEnabledProvider(FeatureKeys.messaging));
});

final tenantReportingEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isTenantModuleEnabledProvider(FeatureKeys.reporting));
});

// ─────────────────────────────────────────
// Registry
// ─────────────────────────────────────────

final allModuleDefsProvider = Provider.autoDispose<List<FeatureDef>>((ref) {
  return FeatureRegistry.features;
});
