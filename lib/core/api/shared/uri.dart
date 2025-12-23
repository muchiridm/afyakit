// lib/core/api/shared/uri.dart

import 'package:flutter/foundation.dart';

String joinBaseAndPath(String base, String path) {
  final b = base.trim().endsWith('/')
      ? base.trim().substring(0, base.trim().length - 1)
      : base.trim();
  final p = path.trim().startsWith('/')
      ? path.trim().substring(1)
      : path.trim();
  if (p.isEmpty) return b;
  return '$b/$p';
}

void debugUri(String label, Uri uri) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('🧭 $label → $uri');
  }
}
