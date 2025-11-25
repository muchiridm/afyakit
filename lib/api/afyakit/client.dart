// lib/api/afyakit/client.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:afyakit/api/shared/http_client.dart';
import 'package:afyakit/api/shared/interceptors.dart';
import 'package:afyakit/api/shared/auth_refresh.dart';

bool _isPublicAuthRoute(String path) =>
    path.contains('/auth_login/check-user-status') ||
    path.contains('/auth_login/wa/start') ||
    path.contains('/auth_login/wa/verify') ||
    path.contains('/auth_login/email/reset');

class AfyaKitClient {
  final Dio dio;
  AfyaKitClient(this.dio);

  static Future<AfyaKitClient> create({
    required String baseUrl,
    required Future<String?> Function() getToken,
    TokenRefresher? refresher,
  }) async {
    // 1) Base HTTP client
    final http = createHttpClient(baseUrl);

    // 🔧 Bump timeouts for slow/core routes (users, HQ invite, etc.)
    http.options = http.options.copyWith(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    );

    // 2) Basic request-id/timing logging
    http.interceptors.add(requestIdAndTiming());

    final tokenRefresher = refresher ?? TokenRefresher();

    // 3) Auth + auto-refresh interceptor
    http.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final isPublic =
              options.extra['skipAuth'] == true ||
              _isPublicAuthRoute(options.uri.path);

          if (!isPublic) {
            try {
              final token = await getToken();
              if ((token ?? '').isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            } catch (e) {
              if (kDebugMode) debugPrint('⚠️ token fetch err: $e');
            }
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          final status = e.response?.statusCode ?? 0;
          final wasRetried = e.requestOptions.extra['retried'] == true;
          final isPublic =
              e.requestOptions.extra['skipAuth'] == true ||
              _isPublicAuthRoute(e.requestOptions.uri.path);

          if (!isPublic &&
              (status == 401 || status == 419 || status == 440) &&
              !wasRetried) {
            final fresh = await tokenRefresher.refreshOnce();
            if ((fresh ?? '').isNotEmpty) {
              final req = e.requestOptions.copyWith(
                headers: {
                  ...e.requestOptions.headers,
                  'Authorization': 'Bearer $fresh',
                },
                extra: {...e.requestOptions.extra, 'retried': true},
              );
              final resp = await http.fetch(req);
              return handler.resolve(resp);
            }
          }
          handler.next(e);
        },
      ),
    );

    return AfyaKitClient(http);
  }
}
