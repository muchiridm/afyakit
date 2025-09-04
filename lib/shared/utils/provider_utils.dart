// lib/shared/providers/provider_utils.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void pLog(String msg) {
  if (kDebugMode) debugPrint(msg);
}

/// Keep an autoDispose provider alive for a fixed duration.
void keepAliveFor(AutoDisposeRef ref, Duration duration) {
  final link = ref.keepAlive();
  Timer(duration, link.close);
}
