import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/core/tenancy/providers/tenant_feature_providers.dart';

typedef RoleGate = bool Function(AuthUser user);
typedef ExtraGate = bool Function(WidgetRef ref, AuthUser user);

final class StaffGate {
  const StaffGate._();

  /// Features come first (tenant). Then role. Then extra.
  static bool allow({
    required WidgetRef ref,
    required AuthUser? user,
    required String featureKey,
    bool featureRequired = true,
    RoleGate? roleGate,
    ExtraGate? extraGate,
  }) {
    if (user == null) return false;

    // 1) FEATURE GATE (tenant)
    if (featureRequired) {
      final enabled = ref.watch(isModuleEnabledProvider(featureKey));
      if (!enabled) return false;
    }

    // 2) ROLE GATE
    if (roleGate != null && roleGate(user) == false) return false;

    // 3) EXTRA GATE (rare)
    if (extraGate != null && extraGate(ref, user) == false) return false;

    return true;
  }
}
