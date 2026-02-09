// lib/core/hq/tenants/controllers/tenant_profile_state.dart

import 'package:afyakit/core/hq/tenants/extensions/tenant_status_x.dart';
import 'package:afyakit/core/hq/tenants/models/feature_registry.dart';
import 'package:afyakit/core/hq/tenants/models/tenant_profile.dart';
import 'package:flutter/foundation.dart';

@immutable
class TenantProfileState {
  const TenantProfileState({
    this.busy = false,
    this.error,
    this.initial,
    this.primaryColorHex = '#2196F3',
    this.currency = 'KES',
    this.status = TenantStatus.active,
    this.features = const <String, bool>{},
    this.showUnknown = false,
  });

  final bool busy;
  final String? error;

  /// Current tenant being edited (null for create)
  final TenantProfile? initial;

  final String primaryColorHex;
  final String currency;
  final TenantStatus status;

  /// All feature flags we will save (includes unknown keys).
  final Map<String, bool> features;

  final bool showUnknown;

  // Sentinel to allow "leave unchanged" vs "set to null"
  static const Object _unset = Object();

  TenantProfileState copyWith({
    bool? busy,
    Object? error = _unset,
    Object? initial = _unset,
    String? primaryColorHex,
    String? currency,
    TenantStatus? status,
    Map<String, bool>? features,
    bool? showUnknown,
  }) {
    return TenantProfileState(
      busy: busy ?? this.busy,
      error: error == _unset ? this.error : error as String?,
      initial: initial == _unset ? this.initial : initial as TenantProfile?,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      features: features ?? this.features,
      showUnknown: showUnknown ?? this.showUnknown,
    );
  }

  /// Keys not present in the registry (legacy / unknown).
  List<String> get unknownFeatureKeys {
    final keys =
        features.keys.where((k) => FeatureRegistry.byKey(k) == null).toList()
          ..sort();
    return keys;
  }

  bool get isCreate => initial == null;
}
