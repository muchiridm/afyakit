// lib/shared/home/models/staff_feature_def.dart

import 'package:afyakit/core/auth_user/extensions/staff_role_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/core/tenancy/models/feature_registry.dart';
import 'package:afyakit/core/tenancy/providers/tenant_feature_providers.dart';

typedef StaffAllowed = bool Function(AuthUser user);
typedef StaffAllowedRef = bool Function(WidgetRef ref, AuthUser user);

@immutable
class StaffFeatureDef {
  const StaffFeatureDef({
    required this.featureKey,
    this.labelOverride,
    this.iconOverride,
    this.descriptionOverride,
    this.destination,
    this.allowed,
    this.allowedRef,
    this.enabledByTenantFeature = true,
  });

  final String featureKey;

  final String? labelOverride;
  final IconData? iconOverride;
  final String? descriptionOverride;

  final WidgetBuilder? destination;

  final StaffAllowed? allowed;
  final StaffAllowedRef? allowedRef;

  final bool enabledByTenantFeature;

  FeatureDef? get feature => FeatureRegistry.byKey(featureKey);

  String get label => labelOverride ?? feature?.label ?? featureKey;

  IconData get icon =>
      iconOverride ?? feature?.icon ?? Icons.extension_outlined;

  String? get description => descriptionOverride ?? feature?.description;

  bool isVisible(WidgetRef ref, AuthUser? user) {
    if (user == null) return false;

    // ✅ OWNER OVERRIDE (enum-safe):
    // We avoid enum identity and check by string, so this works even if there are two StaffRole enums.
    final primary = user.staffRoles.primaryRole;
    final isOwner =
        (primary?.name.toLowerCase() == 'owner') ||
        (primary?.wire.toLowerCase() == 'owner');

    // Owner sees everything, regardless of tenant toggles + per-action gates.
    if (isOwner) return true;

    // 1) Tenant feature gate
    if (enabledByTenantFeature) {
      final enabled = ref.watch(isModuleEnabledProvider(featureKey));
      if (!enabled) return false;
    }

    // 2) User-based gate
    if (allowed != null && allowed!(user) == false) return false;

    // 3) Provider-based gate
    if (allowedRef != null && allowedRef!(ref, user) == false) return false;

    return true;
  }
}
