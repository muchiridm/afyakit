import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

InterceptorsWrapper requestIdAndTiming() => InterceptorsWrapper(
  onRequest: (options, handler) {
    options.extra['rid'] ??=
        (DateTime.now().microsecondsSinceEpoch ^ math.Random().nextInt(1 << 30))
            .toRadixString(36);
    options.extra['t0'] = DateTime.now().millisecondsSinceEpoch;
    options.headers['X-Request-Id'] = options.extra['rid'];
    if (kDebugMode) {
      debugPrint(
        '➡️ [${options.method}] ${options.uri} (#${options.extra['rid']}, retried=${options.extra['retried'] == true})',
      );
    }
    handler.next(options);
  },
  onResponse: (resp, handler) {
    final t0 =
        (resp.requestOptions.extra['t0'] as int?) ??
        DateTime.now().millisecondsSinceEpoch;
    final dt = DateTime.now().millisecondsSinceEpoch - t0;
    if (kDebugMode) {
      debugPrint(
        '✅ ${resp.statusCode} ← ${resp.requestOptions.uri} (#${resp.requestOptions.extra['rid']}, ${dt}ms)',
      );
    }
    handler.next(resp);
  },
  onError: (e, handler) {
    if (kDebugMode) {
      debugPrint(
        '❌ ${e.type} ${e.response?.statusCode ?? 0} on ${e.requestOptions.uri} (#${e.requestOptions.extra['rid']}) data=${e.response?.data}',
      );
    }
    handler.next(e);
  },
);
