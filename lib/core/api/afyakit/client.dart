// lib/core/api/afyakit/client.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:afyakit/core/api/shared/http_client.dart';
import 'package:afyakit/core/api/shared/interceptors.dart';

bool _isPublicAuthRoute(Uri uri) {
  // All login/OTP endpoints are tenant-scoped public endpoints.
  // Examples:
  //   /api/:tenantId/auth_login/check-user-status
  //   /api/:tenantId/auth_login/wa/start
  //   /api/:tenantId/auth_login/sms/start
  //   /api/:tenantId/auth_login/email/start
  //   /api/:tenantId/auth_login/otp/verify
  final p = uri.path;

  if (!p.contains('/auth_login/')) return false;

  // Tighten it: only skip auth for known public auth_login endpoints.
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

class AfyaKitClient {
  final Dio dio;
  AfyaKitClient(this.dio);

  static Future<AfyaKitClient> create({
    required String baseUrl,
    required Future<String?> Function() getToken,
    Future<String?> Function()? getFreshToken,
  }) async {
    final http = createHttpClient(baseUrl);

    http.options = http.options.copyWith(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    );

    http.interceptors.add(requestIdAndTiming());

    http.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Public endpoints must not carry Authorization.
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

          final isPublic = _shouldSkipAuth(options);
          final wasRetried = options.extra['retried'] == true;

          // Retry once on token/session errors.
          final shouldRetry =
              !isPublic &&
              !wasRetried &&
              (status == 401 || status == 419 || status == 440);

          if (!shouldRetry) return handler.next(e);

          try {
            // Force-refresh token on retry (critical for custom claim convergence).
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
              extra: <String, dynamic>{...options.extra, 'retried': true},
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
}
