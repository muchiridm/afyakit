// lib/core/api/afyakit/client.dart

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:afyakit/core/api/shared/http_client.dart';
import 'package:afyakit/core/api/shared/interceptors.dart';

bool _isPublicAuthRoute(Uri uri) {
  final p = uri.path;

  if (!p.contains('/auth_login/')) return false;

  const allowed = <String>[
    '/auth_login/check-user-status',
    '/auth_login/wa/start',
    '/auth_login/sms/start',
    '/auth_login/email/start',
    '/auth_login/otp/verify',
  ];

  return allowed.any(p.contains);
}

bool _shouldSkipAuth(RequestOptions options) {
  final skipAuth = options.extra['skipAuth'] == true;
  if (skipAuth) return true;
  return _isPublicAuthRoute(options.uri);
}

bool _shouldForceFreshToken(RequestOptions options) {
  return options.extra['forceFreshToken'] == true;
}

void _setBearerOrRemoveHeader(RequestOptions options, String? token) {
  final t = token?.trim();
  if (t == null || t.isEmpty) {
    options.headers.remove('Authorization');
    return;
  }
  options.headers['Authorization'] = 'Bearer $t';
}

/// Extra flags used in Dio RequestOptions.extra
final class _ExtraKeys {
  static const retriedAuth = 'retried'; // your existing one
  static const retriedConnTimeout = 'retriedConnTimeout';
}

final class AfyaKitClient {
  final Dio dio;
  AfyaKitClient(this.dio);

  static Future<AfyaKitClient> create({
    required String baseUrl,
    required Future<String?> Function() getToken,
    Future<String?> Function()? getFreshToken,
  }) async {
    final http = createHttpClient(baseUrl);

    // Keep these explicit (even if http_client.dart has defaults) to avoid drift.
    const connectT = Duration(seconds: 30);
    const receiveT = Duration(seconds: 30);
    const sendT = Duration(seconds: 30);

    http.options = http.options.copyWith(
      connectTimeout: connectT,
      receiveTimeout: receiveT,
      sendTimeout: sendT,
    );

    // ─────────────────────────────────────────────
    // Debug: confirm the client we created (baseUrl + timeouts)
    // ─────────────────────────────────────────────
    if (kDebugMode) {
      debugPrint(
        '🧪 [api] init baseUrl=${http.options.baseUrl} '
        'connect=${http.options.connectTimeout} '
        'receive=${http.options.receiveTimeout} '
        'send=${http.options.sendTimeout}',
      );
    }

    // Existing request id + timing interceptor
    http.interceptors.add(requestIdAndTiming());

    // ─────────────────────────────────────────────
    // Debug: always log the exact URL and error type.
    // This is the missing info from your console logs.
    // ─────────────────────────────────────────────
    http.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          if (kDebugMode) {
            debugPrint(
              '🌐 [api] → ${o.method} ${o.uri} '
              'connectTimeout=${o.connectTimeout ?? http.options.connectTimeout}',
            );
          }
          h.next(o);
        },
        onResponse: (r, h) {
          if (kDebugMode) {
            debugPrint(
              '✅ [api] ← ${r.statusCode} ${r.requestOptions.method} ${r.requestOptions.uri}',
            );
          }
          h.next(r);
        },
        onError: (e, h) {
          if (kDebugMode) {
            debugPrint(
              '💥 [api] ✕ ${e.type} ${e.requestOptions.method} ${e.requestOptions.uri} '
              'status=${e.response?.statusCode}',
            );
            debugPrint('💥 [api] msg=${e.message}');
          }
          h.next(e);
        },
      ),
    );

    // ─────────────────────────────────────────────
    // Auth header injector + auth-refresh retry (your logic, preserved)
    // ─────────────────────────────────────────────
    http.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_shouldSkipAuth(options)) {
            options.headers.remove('Authorization');
            return handler.next(options);
          }

          try {
            final token = _shouldForceFreshToken(options)
                ? await (getFreshToken ?? getToken)()
                : await getToken();

            _setBearerOrRemoveHeader(options, token);
          } catch (e) {
            options.headers.remove('Authorization');
            if (kDebugMode) debugPrint('⚠️ [api] token fetch failed: $e');
          }

          return handler.next(options);
        },

        // ✅ Retry rules:
        // 1) Auth retry (401/419/440) - your original behavior.
        // 2) Connection-timeout retry (once) - helps flaky dev networks.
        onError: (e, handler) async {
          final status = e.response?.statusCode ?? 0;
          final options = e.requestOptions;

          // ─────────────────────────────────────────────
          // (A) Retry once on *connection timeout*
          // ─────────────────────────────────────────────
          final wasConnRetried =
              options.extra[_ExtraKeys.retriedConnTimeout] == true;
          final isConnTimeout = e.type == DioExceptionType.connectionTimeout;

          // Only retry idempotent requests by default (GET/HEAD).
          final isIdempotent =
              options.method.toUpperCase() == 'GET' ||
              options.method.toUpperCase() == 'HEAD';

          if (isConnTimeout && !wasConnRetried && isIdempotent) {
            if (kDebugMode) {
              debugPrint(
                '🔁 [api] retrying once after connectionTimeout: ${options.method} ${options.uri}',
              );
            }

            try {
              await Future<void>.delayed(const Duration(milliseconds: 400));

              final req = options.copyWith(
                extra: <String, dynamic>{
                  ...options.extra,
                  _ExtraKeys.retriedConnTimeout: true,
                },
              );

              final resp = await http.fetch(req);
              return handler.resolve(resp);
            } catch (err) {
              if (kDebugMode)
                debugPrint('❌ [api] conn-timeout retry failed: $err');
              // fall through to normal handling
            }
          }

          // ─────────────────────────────────────────────
          // (B) Auth retry (your existing logic)
          // ─────────────────────────────────────────────
          final isPublic = _shouldSkipAuth(options);
          final wasRetriedAuth = options.extra[_ExtraKeys.retriedAuth] == true;

          final shouldRetryAuth =
              !isPublic &&
              !wasRetriedAuth &&
              (status == 401 || status == 419 || status == 440);

          if (!shouldRetryAuth) return handler.next(e);

          try {
            final fresh = await (getFreshToken ?? getToken)();
            final t = fresh?.trim();

            if (t == null || t.isEmpty) {
              if (kDebugMode) {
                debugPrint('⚠️ [api] retry blocked: fresh token is empty');
              }
              return handler.next(e);
            }

            final req = options.copyWith(
              headers: <String, dynamic>{
                ...options.headers,
                'Authorization': 'Bearer $t',
              },
              extra: <String, dynamic>{
                ...options.extra,
                _ExtraKeys.retriedAuth: true,
              },
            );

            final resp = await http.fetch(req);
            return handler.resolve(resp);
          } catch (err) {
            if (kDebugMode) debugPrint('❌ [api] retry failed: $err');
            return handler.next(e);
          }
        },
      ),
    );

    return AfyaKitClient(http);
  }

  // ─────────────────────────────────────────────
  // ✅ Convenience wrappers (Uri-based)
  // ─────────────────────────────────────────────
  //
  // NOTE:
  // AfyaKitRoutes returns a fully-built Uri (including query string),
  // so we DO NOT pass queryParameters here.

  Future<Response<T>> getUri<T>(
    Uri uri, {
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    return dio.getUri<T>(
      uri,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<T>> postUri<T>(
    Uri uri, {
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return dio.postUri<T>(
      uri,
      data: data,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<T>> putUri<T>(
    Uri uri, {
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return dio.putUri<T>(
      uri,
      data: data,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<T>> deleteUri<T>(
    Uri uri, {
    Object? data,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.deleteUri<T>(
      uri,
      data: data,
      options: options,
      cancelToken: cancelToken,
    );
  }
}
