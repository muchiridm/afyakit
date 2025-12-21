import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/config.dart';
import 'package:afyakit/core/api/afyakit/routes.dart';

import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/core/auth/models/start_response.dart';

/// Provides an AuthService bound to a tenant
final authServiceProvider = FutureProvider.family<AuthService, String>((
  ref,
  tenantId,
) async {
  final api = await AfyaKitClient.create(
    baseUrl: apiBaseUrl(tenantId),
    getToken: () async =>
        await fb.FirebaseAuth.instance.currentUser?.getIdToken(),
  );

  return AuthService(
    tenantId: tenantId,
    client: api,
    routes: AfyaKitRoutes(tenantId),
  );
});

class AuthService {
  AuthService({
    required this.tenantId,
    required this.client,
    required this.routes,
  });

  final String tenantId;
  final AfyaKitClient client;
  final AfyaKitRoutes routes;

  fb.FirebaseAuth get _auth => fb.FirebaseAuth.instance;
  Dio get _dio => client.dio;

  AuthUser? _cachedUser;
  AuthUser? get currentUser => _cachedUser;

  // ─────────────────────────────────────────────
  // ✅ Start OTP (per channel)
  // ─────────────────────────────────────────────

  Future<StartResponse> startWaOtp(String phoneE164) async {
    final res = await _dio.postUri(
      routes.waStart(),
      data: {'phoneNumber': phoneE164, 'codeLength': 6},
      options: Options(extra: {'skipAuth': true}),
    );

    final data = (res.data is Map) ? res.data as Map : const {};
    return StartResponse(
      ok: data['ok'] == true,
      throttled: data['throttled'] == true,
      attemptId: data['attemptId'] as String?,
      expiresInSec: (data['expiresInSec'] as num?)?.toInt(),
    );
  }

  Future<StartResponse> startSmsOtp(String phoneE164) async {
    final res = await _dio.postUri(
      routes.smsStart(),
      data: {'phoneNumber': phoneE164, 'codeLength': 6},
      options: Options(extra: {'skipAuth': true}),
    );

    final data = (res.data is Map) ? res.data as Map : const {};
    return StartResponse(
      ok: data['ok'] == true,
      throttled: data['throttled'] == true,
      attemptId: data['attemptId'] as String?,
      expiresInSec: (data['expiresInSec'] as num?)?.toInt(),
    );
  }

  Future<StartResponse> startEmailOtp({
    required String phoneE164,
    required String email,
  }) async {
    final res = await _dio.postUri(
      routes.emailStart(),
      data: {'phoneNumber': phoneE164, 'email': email, 'codeLength': 6},
      options: Options(extra: {'skipAuth': true}),
    );

    final data = (res.data is Map) ? res.data as Map : const {};
    return StartResponse(
      ok: data['ok'] == true,
      throttled: data['throttled'] == true,
      attemptId: data['attemptId'] as String?,
      expiresInSec: (data['expiresInSec'] as num?)?.toInt(),
    );
  }

  // ─────────────────────────────────────────────
  // ✅ Verify OTP (shared across channels)
  // ─────────────────────────────────────────────

  Future<fb.UserCredential> verifyOtp({
    required String phoneE164,
    required String code,
    String? attemptId,
    String? email,
  }) async {
    final payload = <String, dynamic>{'phoneNumber': phoneE164, 'code': code};

    if (attemptId != null && attemptId.isNotEmpty) {
      payload['attemptId'] = attemptId;
    }

    if (email != null && email.trim().isNotEmpty) {
      payload['email'] = email.trim();
    }

    // ignore: avoid_print
    print('[OTP][FE] AuthService.verifyOtp → payload=$payload');

    final res = await _dio.postUri(
      routes.otpVerify(),
      data: payload,
      options: Options(extra: {'skipAuth': true}),
    );

    // ignore: avoid_print
    print('[OTP][FE] AuthService.verifyOtp ← response=${res.data}');

    final token = (res.data is Map) ? res.data['customToken'] as String? : null;
    if (token == null || token.isEmpty) {
      throw StateError('Missing customToken');
    }

    final cred = await _auth.signInWithCustomToken(token);

    // hydrate user cache
    await loadSession();

    return cred;
  }

  // ─────────────────────────────────────────────
  // ✅ Session user (current tenant)
  // ─────────────────────────────────────────────
  Future<AuthUser> loadSession() async {
    final res = await _dio.getUri(routes.getCurrentUser());
    final json = jsonDecode(jsonEncode(res.data)) as Map<String, dynamic>;

    final user = AuthUser.fromMap(json);
    _cachedUser = user;
    return user;
  }

  // ─────────────────────────────────────────────
  // ✅ Session helpers
  // ─────────────────────────────────────────────
  Future<bool> isLoggedIn() async => _auth.currentUser != null;

  Future<void> logOut() async {
    await _auth.signOut();
    _cachedUser = null;
  }
}
