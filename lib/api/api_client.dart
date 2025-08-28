// shared/api/api_client.dart
import 'dart:convert';

import 'package:afyakit/api/api_config.dart';
import 'package:afyakit/hq/core/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiClientProvider = FutureProvider<ApiClient>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final tokenRepo = ref.watch(tokenProvider);
  return ApiClient.create(tenantId: tenantId, tokenProvider: tokenRepo);
});

String apiBaseUrl(String tenantId) => '$baseApiUrl/api/$tenantId';

class ApiClient {
  final Dio dio;
  ApiClient(this.dio);

  String get baseUrl => dio.options.baseUrl;

  /// Factory method to create a new API client
  static Future<ApiClient> create({
    required String tenantId,
    TokenProvider? tokenProvider,
    bool withAuth = true,
  }) async {
    final baseUrl = apiBaseUrl(tenantId);
    if (kDebugMode) debugPrint('🔗 ApiClient Base URL: $baseUrl');

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        contentType: 'application/json',
        // keep sane timeouts if you want:
        // connectTimeout: const Duration(seconds: 20),
        // receiveTimeout: const Duration(seconds: 30),
      ),
    );

    if (!withAuth) {
      if (kDebugMode) {
        debugPrint('🟡 ApiClient: Skipping auth (public request)');
      }
      return ApiClient(dio);
    }
    if (tokenProvider == null) {
      throw Exception('❌ Missing TokenProvider for authenticated request.');
    }

    // Small helper to stringify response data for debug/introspection
    String stringify(dynamic data) {
      if (data == null) return '';
      if (data is String) return data;
      try {
        return jsonEncode(data);
      } catch (_) {
        return data.toString();
      }
    }

    // Attach token on every request
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await tokenProvider.tryGetToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
              if (kDebugMode) {
                debugPrint(
                  '🔐 Interceptor attached token (length: ${token.length})',
                );
              }
            } else {
              if (kDebugMode) debugPrint('⚠️ No token available to attach');
            }
          } catch (e) {
            if (kDebugMode) debugPrint('❌ Token attachment failed: $e');
          }
          return handler.next(options);
        },

        // Handle revoked/expired tokens: force-refresh once and retry
        onError: (e, handler) async {
          final status = e.response?.statusCode ?? 0;
          final wasRetried = e.requestOptions.extra['retried'] == true;

          // signal from server (we set this in middleware) + heuristics
          final authHeader =
              e.response?.headers.value('www-authenticate') ?? '';
          final bodyText = stringify(e.response?.data).toLowerCase();

          final looksAuthError = status == 401 || status == 403;
          final looksRevoked =
              authHeader.toLowerCase().contains('id-token-revoked') ||
              bodyText.contains('id-token-revoked') ||
              bodyText.contains('revoked');

          if (looksAuthError && looksRevoked && !wasRetried) {
            if (kDebugMode) debugPrint('🔁 Token looks revoked → refreshing…');
            try {
              // Force-refresh Firebase ID token
              final user = FirebaseAuth.instance.currentUser;
              final fresh = await user?.getIdToken(true);
              if (fresh != null && fresh.isNotEmpty) {
                // Replay the request once with the fresh token
                final req = e.requestOptions.copyWith(
                  headers: {
                    ...e.requestOptions.headers,
                    'Authorization': 'Bearer $fresh',
                  },
                  extra: {...e.requestOptions.extra, 'retried': true},
                );
                final resp = await dio.fetch(req);
                if (kDebugMode) {
                  debugPrint(
                    '🔁 Retry after refresh → ${resp.statusCode} ${resp.requestOptions.uri}',
                  );
                }
                return handler.resolve(resp);
              }
            } catch (err, st) {
              if (kDebugMode) {
                debugPrint('❌ Token refresh retry failed: $err\n$st');
              }
            }
          }

          // Otherwise, propagate the original error
          return handler.next(e);
        },

        // (Optional) light debug of responses
        onResponse: (resp, handler) {
          if (kDebugMode) {
            final method = resp.requestOptions.method;
            final url = resp.requestOptions.uri;
            debugPrint('🛰️ [$method] ${resp.statusCode} ← $url');
          }
          handler.next(resp);
        },
      ),
    );

    return ApiClient(dio);
  }
}
