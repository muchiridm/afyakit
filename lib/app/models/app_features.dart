// lib/app/models/app_features.dart

import 'package:flutter/foundation.dart';

@immutable
class AppFeatures {
  final Map<String, bool> features;

  const AppFeatures(this.features);

  factory AppFeatures.fromMap(Map<String, dynamic>? map) {
    final source = map ?? const <String, dynamic>{};

    bool toBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) return value.toLowerCase().trim() == 'true';

      return false;
    }

    return AppFeatures({
      for (final entry in source.entries) entry.key: toBool(entry.value),
    });
  }

  bool enabled(String key) => features[key] == true;
}
