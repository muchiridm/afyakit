import 'dart:convert';
import 'package:afyakit/shared/api/api_client.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:afyakit/users/models/auth_user.dart';
import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class UserSessionService {
  final ApiClient client;
  final ApiRoutes routes;
  final TokenProvider tokenProvider;

  UserSessionService({
    required this.client,
    required this.routes,
    required this.tokenProvider,
  });

  String _clean(String? input) => input?.trim() ?? '';

  // ─────────────────────────────────────────────
  // 🔍 Check user status (email or phone)
  // ─────────────────────────────────────────────
  Future<AuthUser> checkUserStatus({String? email, String? phoneNumber}) async {
    final cleanedEmail = _clean(email).toLowerCase();
    final cleanedPhone = _clean(phoneNumber);

    if (cleanedEmail.isEmpty && cleanedPhone.isEmpty) {
      throw ArgumentError('❌ Either email or phoneNumber must be provided');
    }

    final token = await tokenProvider.tryGetToken();
    final uri = routes.checkUserStatus();

    debugPrint('📡 Checking user status: $cleanedEmail / $cleanedPhone');
    debugPrint('🔐 Auth token present: ${token != null}');

    try {
      final response = await client.dio.postUri(
        uri,
        data: {
          if (cleanedEmail.isNotEmpty) 'email': cleanedEmail,
          if (cleanedPhone.isNotEmpty) 'phoneNumber': cleanedPhone,
        },
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );

      final json =
          jsonDecode(jsonEncode(response.data)) as Map<String, dynamic>;
      return AuthUser.fromJson(json);
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? e.message;
      throw Exception('❌ checkUserStatus Dio error: $msg');
    } catch (e) {
      debugPrint('❌ checkUserStatus error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // 📧 Check if email is registered
  // ─────────────────────────────────────────────
  Future<bool> isEmailRegistered(String email) async {
    try {
      final user = await checkUserStatus(email: email);
      return user.uid.isNotEmpty;
    } catch (e) {
      debugPrint('❌ isEmailRegistered error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // 🔐 Send password reset email (via backend)
  // ─────────────────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    final cleanedEmail = EmailHelper.normalize(email);
    if (cleanedEmail.isEmpty) {
      throw ArgumentError('❌ Email is required');
    }

    try {
      final res = await client.dio.postUri(
        routes.sendPasswordResetEmail(),
        data: {'email': cleanedEmail},
      );

      if (res.statusCode != 200) {
        final reason = res.data?['error'] ?? 'Unknown error';
        throw Exception('❌ Failed to send reset email: $reason');
      }

      debugPrint('✅ Password reset email sent to $cleanedEmail');
    } catch (e) {
      debugPrint('❌ sendPasswordResetEmail failed: $e');
      rethrow;
    }
  }
}
