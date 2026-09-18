// lib/core/capabilities/feature_set.dart

import 'package:flutter/foundation.dart';

@immutable
class FeatureSet {
  final Map<String, bool> values;

  const FeatureSet(this.values);

  factory FeatureSet.fromMap(Map<String, dynamic>? map) {
    final source = map ?? const <String, dynamic>{};

    return FeatureSet({
      for (final entry in source.entries) entry.key: _toBool(entry.value),
    });
  }

  bool enabled(String key) => values[key] == true;

  Map<String, bool> toMap() => Map<String, bool>.unmodifiable(values);

  static bool _toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;

    if (value is String) {
      final normalized = value.trim().toLowerCase();

      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'enabled';
    }

    return false;
  }
}
