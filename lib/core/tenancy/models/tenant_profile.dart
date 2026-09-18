// lib/core/tenancy/models/tenant_profile.dart

import 'package:flutter/foundation.dart';

import 'package:afyakit/core/capabilities/feature_set.dart';
import 'package:afyakit/core/tenancy/models/tenant_status_x.dart';
import 'package:afyakit/shared/utils/utils.dart';

@immutable
class TenantProfile {
  /// Invisible backend/data-universe identifier.
  final String id;

  /// Capability ceiling for all apps under this tenant.
  final FeatureSet features;

  /// Allows the entire tenant/data universe to be enabled or disabled.
  final TenantStatus status;

  const TenantProfile({
    required this.id,
    required this.features,
    this.status = TenantStatus.active,
  });

  factory TenantProfile.fromFirestore(String id, JsonObj data) {
    return TenantProfile(
      id: id.trim().toLowerCase(),
      features: FeatureSet.fromMap(_json(data['features'])),
      status: TenantStatusX.parse(_stringOrNull(data['status'])),
    );
  }

  bool has(String featureKey) {
    return features.enabled(featureKey);
  }

  bool get isActive {
    return status.isActive;
  }

  static String? _stringOrNull(Object? value) {
    final text = value?.toString().trim();

    return text == null || text.isEmpty ? null : text;
  }

  static JsonObj _json(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const <String, dynamic>{};
  }
}
