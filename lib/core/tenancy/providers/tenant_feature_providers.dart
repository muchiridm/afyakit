import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/tenancy/models/feature_keys.dart';
import 'package:afyakit/core/tenancy/providers/tenant_profile_providers.dart';

/// Returns true if the tenant has enabled a module key OR one of its sub-keys.
///
/// Examples:
/// - enabled(FeatureKeys.retail) checks:
///     retail == true OR retail.* == true
/// - enabled(FeatureKeys.retailCatalog) checks:
///     retail == true OR retail.catalog == true
final isFeatureEnabledProvider = Provider.autoDispose.family<bool, String>((
  ref,
  key,
) {
  final asyncProfile = ref.watch(tenantProfileProvider);

  return asyncProfile.maybeWhen(
    data: (p) {
      // Direct feature check
      if (p.has(key)) return true;

      // Module root "retail" should enable "retail.catalog" etc.
      // If key is a subfeature, check its root too.
      final dot = key.indexOf('.');
      if (dot > 0) {
        final root = key.substring(0, dot);
        if (p.has(root)) return true;
      }

      // If key is a root module, check any sub-features enabled.
      // (Backward-compatible if tenants only set retail.catalog etc.)
      if (!key.contains('.')) {
        final prefix = '$key.';
        for (final entry in p.features.features.entries) {
          if (entry.value == true && entry.key.startsWith(prefix)) return true;
        }
      }

      return false;
    },
    orElse: () => false,
  );
});

/// Convenience provider for "module enabled" checks.
final isModuleEnabledProvider = Provider.autoDispose.family<bool, String>((
  ref,
  moduleKey,
) {
  // Enforce moduleKey is root-ish, but don't crash.
  return ref.watch(isFeatureEnabledProvider(moduleKey));
});

/// Common booleans used by shells.
// lib/core/tenancy/providers/tenant_feature_providers.dart

final tenantRetailEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isModuleEnabledProvider(FeatureKeys.retail));
});

final tenantInventoryEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isModuleEnabledProvider(FeatureKeys.inventory));
});
