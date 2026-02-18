// lib/core/tenancy/models/tenant_features.dart

import 'package:flutter/foundation.dart';

/// ─────────────────────────────────────────────
/// Features (boolean gates)
/// ─────────────────────────────────────────────
@immutable
class TenantFeatures {
  final Map<String, bool> features;

  const TenantFeatures(this.features);

  factory TenantFeatures.fromMap(Map<String, dynamic>? m) {
    final src = m ?? const <String, dynamic>{};

    bool toBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) return v.toLowerCase() == 'true';
      return false;
    }

    return TenantFeatures({
      for (final e in src.entries) e.key: toBool(e.value),
    });
  }

  bool enabled(String key) => features[key] == true;
}
