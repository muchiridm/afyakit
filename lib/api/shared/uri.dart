import 'package:flutter/foundation.dart';

String joinBaseAndPath(String base, String path) {
  final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  final p = path.startsWith('/') ? path.substring(1) : path;
  return '$b/$p';
}

void debugUri(String label, Uri uri) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('🧭 $label → $uri');
  }
}
