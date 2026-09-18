// lib/features/hq/tenants/controllers/tenant_profile_state.dart

import 'package:flutter/foundation.dart';

import 'package:afyakit/core/capabilities/feature_registry.dart';
import 'package:afyakit/core/tenancy/models/tenant_profile.dart';
import 'package:afyakit/core/tenancy/models/tenant_status_x.dart';

@immutable
class TenantProfileState {
  const TenantProfileState({
    this.busy = false,
    this.error,
    this.initial,
    this.currency = 'KES',
    this.status = TenantStatus.active,
    this.features = const <String, bool>{},
    this.showUnknown = false,
  });

  final bool busy;
  final String? error;

  final TenantProfile? initial;

  final String currency;
  final TenantStatus status;

  final Map<String, bool> features;

  final bool showUnknown;

  static const Object _unset = Object();

  TenantProfileState copyWith({
    bool? busy,
    Object? error = _unset,
    Object? initial = _unset,
    String? currency,
    TenantStatus? status,
    Map<String, bool>? features,
    bool? showUnknown,
  }) {
    return TenantProfileState(
      busy: busy ?? this.busy,
      error: error == _unset ? this.error : error as String?,
      initial: initial == _unset ? this.initial : initial as TenantProfile?,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      features: features ?? this.features,
      showUnknown: showUnknown ?? this.showUnknown,
    );
  }

  List<String> get unknownFeatureKeys {
    final keys =
        features.keys
            .where((key) => FeatureRegistry.byKey(key) == null)
            .toList()
          ..sort();

    return keys;
  }

  bool get isCreate => initial == null;
}
