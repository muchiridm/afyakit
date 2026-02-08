// lib/core/api/afyakit/client.dart

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:afyakit/core/api/shared/http_client.dart';
import 'package:afyakit/core/api/shared/interceptors.dart';

bool _isPublicAuthRoute(Uri uri) {
  final p = uri.path;

  if (!p.contains('/auth_login/')) return false;

  // Only endpoints that are ALWAYS public should live here.
  // Anything "token-gated after login" must NOT be here, otherwise we strip Authorization.
  const allowed = <String>[
    '/auth_login/otp/start',
    '/auth_login/otp/verify',
    '/auth_login/whatsapp/start',
    // '/auth_login/email/start' is DUAL USE:
    // - PUBLIC for login (caller sets skipAuth)
    // - AUTH REQUIRED for purpose=verify_email
    // So it must NEVER be "always public".
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
  static const retriedAuth = 'retried';
  static const retriedConnTimeout = 'retriedConnTimeout';

  static const allow404 = 'allow404';
  static const silence404 = 'silence404';
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

    const connectT = Duration(seconds: 30);
    const receiveT = Duration(seconds: 30);
    const sendT = Duration(seconds: 30);

    http.options = http.options.copyWith(
      connectTimeout: connectT,
      receiveTimeout: receiveT,
      sendTimeout: sendT,
      validateStatus: (code) {
        final c = code ?? 0;
        return c >= 200 && c < 300;
      },
    );

    if (kDebugMode) {
      debugPrint(
        '🧪 [api] init baseUrl=${http.options.baseUrl} '
        'connect=${http.options.connectTimeout} '
        'receive=${http.options.receiveTimeout} '
        'send=${http.options.sendTimeout}',
      );
    }

    http.interceptors.add(requestIdAndTiming());

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
            final status = r.statusCode ?? 0;
            final extra = r.requestOptions.extra;
            final allow404 = extra[_ExtraKeys.allow404] == true;
            final silence404 = extra[_ExtraKeys.silence404] == true;

            if (status == 404 && allow404) {
              if (!silence404) {
                debugPrint(
                  'ℹ️ [api] ← 404 (allowed) ${r.requestOptions.method} ${r.requestOptions.uri}',
                );
              }
              return h.next(r);
            }

            debugPrint(
              '✅ [api] ← $status ${r.requestOptions.method} ${r.requestOptions.uri}',
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

            final data = e.response?.data;
            if (data != null) {
              debugPrint('💥 [api] body=$data');
            }
          }
          h.next(e);
        },
      ),
    );

    // ─────────────────────────────────────────────
    // Auth header injector + auth-refresh retry
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
        onError: (e, handler) async {
          final status = e.response?.statusCode ?? 0;
          final options = e.requestOptions;

          final wasConnRetried =
              options.extra[_ExtraKeys.retriedConnTimeout] == true;
          final isConnTimeout = e.type == DioExceptionType.connectionTimeout;

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
              if (kDebugMode) {
                debugPrint('❌ [api] conn-timeout retry failed: $err');
              }
            }
          }

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
  // Convenience wrappers
  // ─────────────────────────────────────────────

  Options _mergeOptions(Options? options, {required bool allow404}) {
    final extra = <String, dynamic>{
      ...?options?.extra,
      if (allow404) _ExtraKeys.allow404: true,
    };

    return (options ?? Options()).copyWith(
      extra: extra,
      validateStatus: (code) {
        final c = code ?? 0;
        if (allow404 && c == 404) return true;
        return c >= 200 && c < 300;
      },
    );
  }

  Future<Response<T>> getUri<T>(
    Uri uri, {
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    bool allow404 = false,
  }) {
    return dio.getUri<T>(
      uri,
      options: _mergeOptions(options, allow404: allow404),
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
    bool allow404 = false,
  }) {
    return dio.postUri<T>(
      uri,
      data: data,
      options: _mergeOptions(options, allow404: allow404),
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
    bool allow404 = false,
  }) {
    return dio.putUri<T>(
      uri,
      data: data,
      options: _mergeOptions(options, allow404: allow404),
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
    bool allow404 = false,
  }) {
    return dio.deleteUri<T>(
      uri,
      data: data,
      options: _mergeOptions(options, allow404: allow404),
      cancelToken: cancelToken,
    );
  }
}
