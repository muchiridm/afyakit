// lib/core/api/shared/interceptors.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

String _mkRid(RequestOptions o) {
  final us = DateTime.now().microsecondsSinceEpoch;
  final h = o.hashCode & 0x3fffffff;
  return (us ^ h).toRadixString(36);
}

InterceptorsWrapper requestIdAndTiming() => InterceptorsWrapper(
  onRequest: (options, handler) {
    options.extra['rid'] ??= _mkRid(options);
    options.extra['t0'] = DateTime.now();

    options.headers['X-Request-Id'] = options.extra['rid'];

    if (kDebugMode) {
      final rid = options.extra['rid'];
      final retried = options.extra['retried'] == true;
      debugPrint(
        '➡️ [${options.method}] ${options.uri} (#$rid, retried=$retried)',
      );
    }

    handler.next(options);
  },
  onResponse: (resp, handler) {
    final t0 = resp.requestOptions.extra['t0'] as DateTime?;
    final dt = t0 == null ? null : DateTime.now().difference(t0).inMilliseconds;

    if (kDebugMode) {
      final rid = resp.requestOptions.extra['rid'];
      debugPrint(
        '✅ ${resp.statusCode} ← ${resp.requestOptions.uri} (#$rid${dt != null ? ', ${dt}ms' : ''})',
      );
    }

    handler.next(resp);
  },
  onError: (e, handler) {
    if (kDebugMode) {
      final rid = e.requestOptions.extra['rid'];
      final code = e.response?.statusCode ?? 0;
      debugPrint(
        '❌ ${e.type} $code on ${e.requestOptions.uri} (#$rid) data=${e.response?.data}',
      );
    }
    handler.next(e);
  },
);
