// lib/api/api_client.dart
import 'dart:async';
import 'dart:math' as math; // ← for short request ids
import 'package:afyakit/api/api_config.dart';
import 'package:afyakit/hq/core/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/core/auth_users/providers/auth_session/token_provider.dart';
import 'package:afyakit/shared/utils/dev_trace.dart'; // ← ADD
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String apiBaseUrl(String tenantId) => '$baseApiUrl/api/$tenantId';

final apiClientProvider = FutureProvider<ApiClient>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final tokenRepo = ref.watch(tokenProvider);
  return ApiClient.create(tenantId: tenantId, tokenProvider: tokenRepo);
});

class ApiClient {
  final Dio dio;
  ApiClient(this.dio);

  String get baseUrl => dio.options.baseUrl;

  static Future<ApiClient> create({
    required String tenantId,
    TokenProvider? tokenProvider,
    bool withAuth = true,
  }) async {
    final span = DevTrace(
      'apiClient.create',
      context: {'tenant': tenantId, 'withAuth': withAuth},
    );

    final baseUrl = apiBaseUrl(tenantId);
    span.log('baseUrl', add: {'url': baseUrl});
    if (kDebugMode) debugPrint('🔗 ApiClient Base URL: $baseUrl');

    final http = Dio(
      BaseOptions(baseUrl: baseUrl, contentType: 'application/json'),
    );

    if (!withAuth) {
      span.done('no-auth http client ready');
      return ApiClient(http);
    }
    if (tokenProvider == null) {
      span.done('missing tokenProvider');
      throw Exception('❌ Missing TokenProvider for authenticated request.');
    }

    // ── Single-flight refresh guard ─────────────────────────────
    Future<String?>? refreshing;
    Future<String?> refreshOnce() {
      if (refreshing != null) return refreshing!;
      final c = Completer<String?>();
      refreshing = c.future;
      () async {
        final t = DevTrace('token.refresh', context: {'tenant': tenantId});
        try {
          final u = fb.FirebaseAuth.instance.currentUser;
          if (u == null) {
            t.done('no-currentUser');
            c.complete(null);
            return;
          }
          final fresh = await u
              .getIdToken(true)
              .timeout(const Duration(seconds: 8));
          t.log('refreshed', add: {'len': fresh?.length ?? 0});
          c.complete(fresh);
        } on fb.FirebaseAuthException catch (e) {
          t.done('auth-ex ${e.code}');
          c.complete(null);
        } catch (e, st) {
          t.done('error $e');
          if (kDebugMode) debugPrint('$st');
          c.complete(null);
        } finally {
          refreshing = null;
        }
      }();
      return c.future;
    }

    // ── Interceptors with request id + timings ─────────────────
    http.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Correlate every attempt
          options.extra['rid'] ??=
              (DateTime.now().microsecondsSinceEpoch ^
                      math.Random().nextInt(1 << 30))
                  .toRadixString(36);
          options.extra['t0'] = DateTime.now().millisecondsSinceEpoch;

          final rid = options.extra['rid'];
          // Carry correlation id to backend logs
          options.headers['X-Request-Id'] = rid;

          if (kDebugMode) {
            debugPrint(
              '➡️  [${options.method}] ${options.uri} '
              '(#$rid, retried=${options.extra['retried'] == true})',
            );
          }

          try {
            final token = await tokenProvider.tryGetToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            // If a refresh is in-flight, wait to ride on the fresh token
            if (refreshing != null) {
              final fresh = await refreshOnce();
              if ((fresh ?? '').isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $fresh';
              }
            }
          } catch (e) {
            if (kDebugMode) debugPrint('⚠️ onRequest token fetch err: $e');
          }
          handler.next(options);
        },

        onResponse: (resp, handler) {
          final rid = resp.requestOptions.extra['rid'];
          final t0 =
              (resp.requestOptions.extra['t0'] as int?) ??
              DateTime.now().millisecondsSinceEpoch;
          final dt = DateTime.now().millisecondsSinceEpoch - t0;
          if (kDebugMode) {
            debugPrint(
              '✅ ${resp.statusCode} ← ${resp.requestOptions.uri} (#$rid, ${dt}ms)',
            );
          }
          handler.next(resp);
        },

        onError: (e, handler) async {
          final status = e.response?.statusCode ?? 0;
          final wasRetried = e.requestOptions.extra['retried'] == true;
          final rid = e.requestOptions.extra['rid'];

          // Only these get refresh+single retry
          final shouldRetryWithRefresh =
              (status == 401 || status == 419 || status == 440) && !wasRetried;

          if (shouldRetryWithRefresh) {
            debugPrint(
              '🔁 $status on ${e.requestOptions.uri} (#$rid) → refresh & retry',
            );
            String? fresh;
            try {
              fresh = await refreshOnce();
            } catch (_) {
              fresh = null;
            }

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
            if (kDebugMode) {
              debugPrint('⚠️ (#$rid) refresh failed → surface $status');
            }
            // fall through to propagate the original error
          }

          // IMPORTANT: Let all other 4xx propagate as errors (don’t "resolve"/passthrough).
          return handler.next(e);
        },
      ),
    );

    span.done('auth http client ready');
    return ApiClient(http);
  }
}
