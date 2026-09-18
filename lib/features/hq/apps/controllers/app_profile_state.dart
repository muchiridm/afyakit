// lib/features/hq/apps/controllers/app_profile_state.dart

import 'package:flutter/foundation.dart';

import 'package:afyakit/app/models/app_profile.dart';
import 'package:afyakit/core/tenancy/models/tenant_profile.dart';

@immutable
class AppProfileEditorInput {
  const AppProfileEditorInput({required this.tenant, this.initial});

  final TenantProfile tenant;
  final AppProfile? initial;
}

@immutable
class AppProfileState {
  const AppProfileState({
    this.busy = false,
    this.error,
    this.tenant,
    this.initial,
    this.active = true,
    this.features = const <String, bool>{},
  });

  final bool busy;
  final String? error;

  final TenantProfile? tenant;
  final AppProfile? initial;

  final bool active;

  /// App feature exposure.
  ///
  /// Must remain a subset of tenant.features.
  final Map<String, bool> features;

  static const Object _unset = Object();

  bool get isCreate => initial == null;

  AppProfileState copyWith({
    bool? busy,
    Object? error = _unset,
    Object? tenant = _unset,
    Object? initial = _unset,
    bool? active,
    Map<String, bool>? features,
  }) {
    return AppProfileState(
      busy: busy ?? this.busy,
      error: error == _unset ? this.error : error as String?,
      tenant: tenant == _unset ? this.tenant : tenant as TenantProfile?,
      initial: initial == _unset ? this.initial : initial as AppProfile?,
      active: active ?? this.active,
      features: features ?? this.features,
    );
  }
}
