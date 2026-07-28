// lib/core/home/models/staff_entry_def.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/hq/tenants/models/feature_registry.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_feature_providers.dart';
import 'package:afyakit/core/home/models/staff_feature_def.dart';

enum StaffEntryKind { featureTile, quickAction }

@immutable
class StaffEntryDef {
  const StaffEntryDef({
    required this.kind,
    required this.featureKey,
    this.labelOverride,
    this.iconOverride,
    this.descriptionOverride,
    this.destination,
    this.allowed,
    this.allowedRef,
    this.enabledByTenantFeature = true,
  });

  final StaffEntryKind kind;

  /// Tenant feature bucket this entry belongs to:
  /// inventory, clinical, retail, hq, etc.
  final String featureKey;

  final String? labelOverride;
  final IconData? iconOverride;
  final String? descriptionOverride;

  final WidgetBuilder? destination;

  final StaffAllowed? allowed;
  final StaffAllowedRef? allowedRef;

  /// Whether this entry is controlled by tenant feature toggles.
  final bool enabledByTenantFeature;

  FeatureDef? get feature => FeatureRegistry.byKey(featureKey);

  String get label => labelOverride ?? feature?.label ?? featureKey;

  IconData get icon =>
      iconOverride ?? feature?.icon ?? Icons.extension_outlined;

  String? get description => descriptionOverride ?? feature?.description;

  bool isVisible(WidgetRef ref, AuthUser? user) {
    if (user == null) return false;

    if (enabledByTenantFeature) {
      final enabled = ref.watch(isModuleEnabledProvider(featureKey));
      if (!enabled) return false;
    }

    if (allowed != null && allowed!(user) == false) return false;

    if (allowedRef != null && allowedRef!(ref, user) == false) return false;

    return true;
  }

  StaffFeatureDef toFeatureDef() {
    return StaffFeatureDef(
      featureKey: featureKey,
      labelOverride: labelOverride,
      iconOverride: iconOverride,
      descriptionOverride: descriptionOverride,
      destination: destination,
      allowed: allowed,
      allowedRef: allowedRef,
      enabledByTenantFeature: enabledByTenantFeature,
    );
  }
}
