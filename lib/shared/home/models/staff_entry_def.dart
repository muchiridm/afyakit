import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/auth_user/models/auth_user_model.dart';

typedef RoleGate = bool Function(AuthUser user);
typedef ExtraGate = bool Function(WidgetRef ref, AuthUser user);

enum StaffEntryKind { featureTile, quickAction }

@immutable
class StaffEntryDef {
  const StaffEntryDef({
    required this.kind,
    required this.featureKey,
    required this.label,
    required this.icon,
    this.description,
    this.destination,
    this.featureRequired = true,
    this.roleGate,
    this.extraGate,
  });

  final StaffEntryKind kind;

  /// The tenant feature key this entry belongs to (inventory, retail, etc.)
  final String featureKey;

  final String label;
  final IconData icon;
  final String? description;

  final WidgetBuilder? destination;

  /// Some entries (e.g. Admin) aren’t controlled by tenant feature toggles.
  final bool featureRequired;

  /// Pure role/claims gate
  final RoleGate? roleGate;

  /// Rare: needs providers (tenant profile, config, etc.)
  final ExtraGate? extraGate;
}
