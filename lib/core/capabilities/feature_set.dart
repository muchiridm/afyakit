// lib/core/capabilities/feature_set.dart

import 'package:flutter/foundation.dart';

@immutable
class FeatureSet {
  const FeatureSet(this.values);

  final Map<String, bool> values;

  factory FeatureSet.fromMap(Map<String, dynamic>? map) {
    final source = map ?? const <String, dynamic>{};

    return FeatureSet({
      for (final entry in source.entries)
        _normalize(entry.key): _toBool(entry.value),
    });
  }

  bool enabled(String key) {
    return values[_normalize(key)] == true;
  }

  Map<String, bool> toMap() {
    return Map<String, bool>.unmodifiable(values);
  }

  static String _normalize(String key) {
    return key.trim().toLowerCase();
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;

    if (value is num) return value != 0;

    if (value is String) {
      return switch (value.trim().toLowerCase()) {
        'true' || '1' || 'yes' || 'enabled' => true,
        _ => false,
      };
    }

    return false;
  }
}
