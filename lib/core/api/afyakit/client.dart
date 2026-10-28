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
  // Anything "token-gated after login" must NOT be here,
  // otherwise we strip Authorization.
  const allowed = <String>[
    '/auth_login/otp/start',
    '/auth_login/otp/verify',
    '/auth_login/whatsapp/start',

    // '/auth_login/email/start' is DUAL USE:
    // - PUBLIC for login (caller sets skipAuth)
    // - AUTH REQUIRED for purpose=verify_email
    //
    // So it must NEVER be "always public".
  ];

  return allowed.any(p.contains);
}

bool _shouldSkipAuth(RequestOptions options) {
  final skipAuth = options.extra['skipAuth'] == true;

  if (skipAuth) {
    return true;
  }

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

String _normaliseAppId(String value) {
  final appId = value.trim().toLowerCase();

  if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(appId)) {
    throw ArgumentError.value(value, 'appId', 'Invalid AfyaKit app ID');
  }

  return appId;
}

/// Extra flags used in Dio RequestOptions.extra.
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
    required String appId,
    required Future<String?> Function() getToken,
    Future<String?> Function()? getFreshToken,
  }) async {
    final cleanAppId = _normaliseAppId(appId);

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
        '🧪 [api] init '
        'baseUrl=${http.options.baseUrl} '
        'appId=$cleanAppId '
        'connect=${http.options.connectTimeout} '
        'receive=${http.options.receiveTimeout} '
        'send=${http.options.sendTimeout}',
      );
    }

    http.interceptors.add(requestIdAndTiming());

    http.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          /*
           * The running app identity is supplied by the
           * AfyaKitClient factory and is authoritative.
           *
           * Do not trust a caller-supplied x-app-id:
           * individual services must not be able to switch
           * app context on a shared client.
           */
          options.headers['x-app-id'] = cleanAppId;

          if (kDebugMode) {
            debugPrint(
              '🌐 [api] → '
              '${options.method} '
              '${options.uri} '
              'app=$cleanAppId '
              'connectTimeout='
              '${options.connectTimeout ?? http.options.connectTimeout}',
            );
          }

          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            final status = response.statusCode ?? 0;

            final extra = response.requestOptions.extra;

            final allow404 = extra[_ExtraKeys.allow404] == true;

            final silence404 = extra[_ExtraKeys.silence404] == true;

            if (status == 404 && allow404) {
              if (!silence404) {
                debugPrint(
                  'ℹ️ [api] ← 404 (allowed) '
                  '${response.requestOptions.method} '
                  '${response.requestOptions.uri}',
                );
              }

              return handler.next(response);
            }

            debugPrint(
              '✅ [api] ← $status '
              '${response.requestOptions.method} '
              '${response.requestOptions.uri}',
            );
          }

          handler.next(response);
        },
        onError: (error, handler) {
          if (kDebugMode) {
            debugPrint(
              '💥 [api] ✕ '
              '${error.type} '
              '${error.requestOptions.method} '
              '${error.requestOptions.uri} '
              'status='
              '${error.response?.statusCode}',
            );

            debugPrint('💥 [api] msg=${error.message}');

            final data = error.response?.data;

            if (data != null) {
              debugPrint('💥 [api] body=$data');
            }
          }

          handler.next(error);
        },
      ),
    );

    // ─────────────────────────────────────────────
    // Auth header injector + auth-refresh retry
    // ─────────────────────────────────────────────

    http.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          /*
           * Re-assert app identity here as well.
           *
           * The logging interceptor above runs first, but
           * all AfyaKit requests must reach the server with
           * the canonical app header even if another
           * interceptor or request Options attempted to
           * modify it.
           */
          options.headers['x-app-id'] = cleanAppId;

          if (_shouldSkipAuth(options)) {
            options.headers.remove('Authorization');

            return handler.next(options);
          }

          try {
            final token = _shouldForceFreshToken(options)
                ? await (getFreshToken ?? getToken)()
                : await getToken();

            _setBearerOrRemoveHeader(options, token);
          } catch (error) {
            options.headers.remove('Authorization');

            if (kDebugMode) {
              debugPrint(
                '⚠️ [api] token fetch failed: '
                '$error',
              );
            }
          }

          return handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode ?? 0;

          final options = error.requestOptions;

          final wasConnRetried =
              options.extra[_ExtraKeys.retriedConnTimeout] == true;

          final isConnTimeout =
              error.type == DioExceptionType.connectionTimeout;

          final method = options.method.toUpperCase();

          final isIdempotent = method == 'GET' || method == 'HEAD';

          if (isConnTimeout && !wasConnRetried && isIdempotent) {
            if (kDebugMode) {
              debugPrint(
                '🔁 [api] retrying once '
                'after connectionTimeout: '
                '${options.method} '
                '${options.uri}',
              );
            }

            try {
              await Future<void>.delayed(const Duration(milliseconds: 400));

              final req = options.copyWith(
                headers: <String, dynamic>{
                  ...options.headers,
                  'x-app-id': cleanAppId,
                },
                extra: <String, dynamic>{
                  ...options.extra,
                  _ExtraKeys.retriedConnTimeout: true,
                },
              );

              final response = await http.fetch(req);

              return handler.resolve(response);
            } catch (retryError) {
              if (kDebugMode) {
                debugPrint(
                  '❌ [api] conn-timeout '
                  'retry failed: '
                  '$retryError',
                );
              }
            }
          }

          final isPublic = _shouldSkipAuth(options);

          final wasRetriedAuth = options.extra[_ExtraKeys.retriedAuth] == true;

          final shouldRetryAuth =
              !isPublic &&
              !wasRetriedAuth &&
              (status == 401 || status == 419 || status == 440);

          if (!shouldRetryAuth) {
            return handler.next(error);
          }

          try {
            final fresh = await (getFreshToken ?? getToken)();

            final token = fresh?.trim();

            if (token == null || token.isEmpty) {
              if (kDebugMode) {
                debugPrint(
                  '⚠️ [api] retry blocked: '
                  'fresh token is empty',
                );
              }

              return handler.next(error);
            }

            final req = options.copyWith(
              headers: <String, dynamic>{
                ...options.headers,

                /*
                         * Keep app identity immutable
                         * through an auth retry.
                         */
                'x-app-id': cleanAppId,

                'Authorization': 'Bearer $token',
              },
              extra: <String, dynamic>{
                ...options.extra,
                _ExtraKeys.retriedAuth: true,
              },
            );

            final response = await http.fetch(req);

            return handler.resolve(response);
          } catch (retryError) {
            if (kDebugMode) {
              debugPrint(
                '❌ [api] retry failed: '
                '$retryError',
              );
            }

            return handler.next(error);
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

        if (allow404 && c == 404) {
          return true;
        }

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

  Future<Response<T>> requestUri<T>(
    Uri uri, {
    required String method,
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    bool allow404 = false,
  }) {
    final m = method.trim().toUpperCase();

    if (m.isEmpty) {
      throw ArgumentError.value(method, 'method', 'HTTP method is required');
    }

    return dio.requestUri<T>(
      uri,
      data: data,
      options: _mergeOptions(options, allow404: allow404).copyWith(method: m),
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<T>> patchUri<T>(
    Uri uri, {
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    bool allow404 = false,
  }) {
    return requestUri<T>(
      uri,
      method: 'PATCH',
      data: data,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      allow404: allow404,
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
