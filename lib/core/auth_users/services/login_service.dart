// lib/core/auth_users/services/login_service.dart
import 'dart:convert';
import 'dart:math' as math;

import 'package:afyakit/api/api_client.dart';
import 'package:afyakit/api/api_routes.dart';
import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/models/wa_start_response.dart';
import 'package:afyakit/core/auth_users/providers/auth_session/token_provider.dart';
import 'package:afyakit/shared/utils/dev_trace.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Login (Firebase-only)
final loginServiceFirebaseOnlyProvider = Provider<LoginService>(
  (_) => LoginService.firebaseOnly(),
);

/// Login with backend (claims sync, backend reset, WA)
final loginServiceProvider = FutureProvider.family<LoginService, String>((
  ref,
  tenantId,
) async {
  final api = await ApiClient.create(
    tenantId: tenantId,
    tokenProvider: ref.read(tokenProvider),
    withAuth: true, // headers ignored by public routes; safe to keep
  );
  return LoginService.createWithBackend(tenantId: tenantId, client: api);
});

class LoginService {
  LoginService._(this._auth, this._client, this._routes);

  final fb.FirebaseAuth _auth;
  final ApiClient? _client; // needed for backend calls
  final ApiRoutes? _routes;

  factory LoginService.firebaseOnly() =>
      LoginService._(fb.FirebaseAuth.instance, null, null);

  static Future<LoginService> createWithBackend({
    required String tenantId,
    required ApiClient client,
  }) async =>
      LoginService._(fb.FirebaseAuth.instance, client, ApiRoutes(tenantId));

  String? get expectedTenantId => _routes?.tenantId;

  // ── state ───────────────────────────────────────────────────
  fb.User? get currentUser => _auth.currentUser;
  Future<bool> isLoggedIn() async => _auth.currentUser != null;

  Future<void> signOut() async {
    final email = _auth.currentUser?.email;
    await _auth.signOut();
    debugPrint('🔒 User signed out: $email');
  }

  Future<void> waitForUser() async {
    try {
      await _auth.authStateChanges().first.timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
      final u = _auth.currentUser;
      debugPrint(
        u != null
            ? '✅ Firebase user restored: ${u.email}'
            : '👻 No Firebase user',
      );
    } catch (_) {
      debugPrint('⏳ FirebaseAuth hydration timed out.');
    }
  }

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final u = _auth.currentUser;
    return u?.getIdToken(forceRefresh);
  }

  // ── EMAIL + PASSWORD ────────────────────────────────────────
  Future<fb.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    debugPrint('🔓 Signed in as: ${cred.user?.email}');
    await _syncClaimsIfPossible();
    return cred;
  }

  /// Prefer backend reset (custom action link), fallback to Firebase client.
  Future<void> sendPasswordResetEmail(
    String email, {
    bool viaBackend = true,
  }) async {
    if (!viaBackend || _client == null || _routes == null) {
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('✅ (Client) Password reset email sent to $email');
      return;
    }

    final t = DevTrace('password-reset', context: {'tenant': _routes.tenantId});
    try {
      final uri = _routes
          .emailResetLogin(); // /:tenantId/auth_login/email/reset
      t.log('POST', add: {'uri': uri.toString()});
      final res = await _client.dio.postUri(uri, data: {'email': email});
      if ((res.statusCode ?? 0) ~/ 100 != 2) {
        throw StateError('backend-reset-failed ${res.statusCode}');
      }
      t.done('ok-auth_login');
      debugPrint('✅ (Backend auth_login) Password reset email sent to $email');
    } catch (_) {
      await _auth.sendPasswordResetEmail(email: email);
      t.done('fallback-client');
      debugPrint('✅ (Client fallback) Password reset email sent to $email');
    }
  }

  // ── WhatsApp OTP ────────────────────────────────────────────
  Future<WaStartResponse> waStartLogin({
    required String phoneE164,
    String purpose = 'login', // 'login' | 'invite'
    int codeLength = 6,
  }) async {
    _ensureBackend();
    final uri = _routes!.waStart(); // /:tenantId/auth_login/wa/start
    final res = await _client!.dio.postUri(
      uri,
      data: {
        'phoneNumber': phoneE164,
        'purpose': purpose,
        'codeLength': codeLength,
      },
    );
    final data = (res.data is Map) ? res.data as Map : const {};
    return WaStartResponse(
      ok: data['ok'] == true,
      throttled: data['throttled'] == true,
      attemptId: data['attemptId'] as String?,
      expiresInSec: (data['expiresInSec'] as num?)?.toInt(),
    );
  }

  Future<fb.UserCredential> waVerifyAndSignIn({
    required String phoneE164,
    required String code,
    String? attemptId,
  }) async {
    _ensureBackend();
    final uri = _routes!.waVerify(); // /:tenantId/auth_login/wa/verify
    final res = await _client!.dio.postUri(
      uri,
      data: {
        'phoneNumber': phoneE164,
        'code': code,
        if (attemptId != null && attemptId.isNotEmpty) 'attemptId': attemptId,
      },
    );

    final status = res.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      final err = res.data is Map ? (res.data as Map)['error'] : 'UNKNOWN';
      throw Exception('WA verify failed: $err');
    }

    final data = res.data as Map;
    final token = data['customToken'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Missing customToken from WA verify response');
    }

    final cred = await _auth.signInWithCustomToken(token);
    await _syncClaimsIfPossible();
    return cred;
  }

  // ── Public pre-checks ───────────────────────────────────────
  /// `/:tenantId/auth_login/check-user-status`
  // in lib/core/auth_users/services/login_service.dart

  Future<AuthUser> checkUserStatus({String? email, String? phoneNumber}) async {
    _ensureBackend();

    final cleanedEmail = (email ?? '').trim().toLowerCase();
    final cleanedPhone = (phoneNumber ?? '').trim();
    if (cleanedEmail.isEmpty && cleanedPhone.isEmpty) {
      throw ArgumentError('Either email or phoneNumber must be provided.');
    }

    String maskPhone(String p) {
      if (p.isEmpty) return p;
      if (p.length <= 6) return '${p.substring(0, math.min(3, p.length))}…';
      return '${p.substring(0, 4)}…${p.substring(p.length - 2)}';
    }

    final uri = _routes!.checkUserStatus();
    final t = DevTrace(
      'auth_login.checkUserStatus',
      context: {
        'tenant': _routes.tenantId,
        'email': cleanedEmail.isNotEmpty ? cleanedEmail : null,
        'phone': cleanedPhone.isNotEmpty ? maskPhone(cleanedPhone) : null,
      },
    );

    try {
      t.log('POST', add: {'uri': uri.toString(), 'public': true});

      final res = await _client!.dio.postUri(
        uri,
        data: {
          if (cleanedEmail.isNotEmpty) 'email': cleanedEmail,
          if (cleanedPhone.isNotEmpty) 'phoneNumber': cleanedPhone,
        },
        // Public route: no Authorization header, no refresh dance.
        options: Options(extra: {'skipAuth': true}),
      );

      final json = jsonDecode(jsonEncode(res.data)) as Map<String, dynamic>;
      final user = AuthUser.fromJson(json);

      t.done('ok → ${user.status.name} uid=${user.uid}');
      return user;
    } on DioException catch (e) {
      final sc = e.response?.statusCode ?? 0;
      final body = e.response?.data;
      t.done('http-$sc');
      debugPrint(
        '❌ check-user-status failed [$sc] ${uri.toString()} '
        'body=${body is Map ? jsonEncode(body) : body}',
      );
      rethrow; // preserve existing error handling upstream
    } catch (e) {
      t.done('error');
      debugPrint('❌ check-user-status unexpected error: $e');
      rethrow;
    }
  }

  /// Convenience wrapper around `checkUserStatus`.
  Future<bool> isEmailRegistered(String email) async {
    try {
      await checkUserStatus(email: email);
      return true; // 2xx → known
    } on DioException catch (e) {
      final sc = e.response?.statusCode ?? 0;
      if (sc == 404) return false; // not found
      return true; // other errors → don’t block UX
    } catch (_) {
      return false;
    }
  }

  // ── internal helpers ────────────────────────────────────────
  void _ensureBackend() {
    if (_client == null || _routes == null) {
      throw StateError(
        'LoginService requires backend-enabled instance for this call.',
      );
    }
  }

  Future<void> _syncClaimsIfPossible() async {
    if (_client == null || _routes == null) return;
    try {
      final uri = _routes.syncClaims();
      final res = await _client.dio.postUri(uri);
      if ((res.statusCode ?? 0) ~/ 100 != 2) {
        if (kDebugMode) {
          debugPrint('⚠️ sync-claims non-2xx: ${res.statusCode} ${res.data}');
        }
      } else if (kDebugMode) {
        debugPrint('✅ Claims synced: ${res.data}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ sync-claims failed: $e');
    }
  }
}
