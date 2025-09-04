// lib/shared/utils/dev_trace.dart
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

class DevTrace {
  final String id;
  final String label;
  final Stopwatch _sw = Stopwatch()..start();
  final Map<String, Object?> ctx;
  DevTrace(this.label, {Map<String, Object?>? context})
    : id = _randId(),
      ctx = context ?? const {};

  static String _randId() {
    final r = math.Random();
    final n = r.nextInt(0x7fffffff);
    return n.toRadixString(36);
  }

  String _prefix() => '⏱ ${_sw.elapsed.inMilliseconds}ms [$label#$id]';

  void log(String msg, {Map<String, Object?> add = const {}}) {
    if (!kDebugMode) return;
    final merged = {...ctx, ...add}
      ..removeWhere((k, v) => v == null || v == '');
    debugPrint('${_prefix()} $msg ${merged.isEmpty ? '' : '→ $merged'}');
  }

  void done([String msg = 'done']) {
    if (!kDebugMode) return;
    debugPrint('${_prefix()} $msg');
  }
}
