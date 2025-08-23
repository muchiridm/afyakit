// shared/api/api_client.dart
import 'package:afyakit/shared/api/api_client_base.dart';
import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  final Dio dio;
  ApiClient(this.dio);

  // ✅ Expose baseUrl so callers can log/use it
  String get baseUrl => dio.options.baseUrl;

  /// Factory method to create a new API client
  static Future<ApiClient> create({
    required String tenantId,
    TokenProvider? tokenProvider,
    bool withAuth = true,
  }) async {
    final baseUrl = apiBaseUrl(tenantId);
    debugPrint('🔗 ApiClient Base URL: $baseUrl');

    final dio = Dio(
      BaseOptions(baseUrl: baseUrl, contentType: 'application/json'),
    );

    if (withAuth) {
      if (tokenProvider == null) {
        throw Exception('❌ Missing TokenProvider for authenticated request.');
      }

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            try {
              final token = await tokenProvider.tryGetToken();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
                debugPrint(
                  '🔐 Interceptor attached token (length: ${token.length})',
                );
              } else {
                debugPrint('⚠️ No token available to attach');
              }
            } catch (e) {
              debugPrint('❌ Token attachment failed: $e');
            }
            return handler.next(options);
          },
        ),
      );
    } else {
      debugPrint('🟡 ApiClient: Skipping auth (public request)');
    }

    return ApiClient(dio);
  }
}
