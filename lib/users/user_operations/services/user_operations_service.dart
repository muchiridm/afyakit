// lib/user_operations/user_operations_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:afyakit/shared/api/api_client.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:afyakit/users/user_manager/models/auth_user_model.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userOperationsServiceProvider =
    FutureProvider.family<UserOperationsService, String>((ref, tenantId) async {
      final tokens = ref.read(tokenProvider);
      return UserOperationsService.createWithBackend(
        tenantId: tenantId,
        tokenProvider: tokens,
        withAuth: true,
      );
    });

final firebaseOnlyUserOpsProvider = Provider<UserOperationsService>(
  (_) => UserOperationsService.firebaseOnly(),
);

class UserOperationsService {
  final FirebaseAuth _auth;
  final ApiClient? _client; // optional (backend-enabled)
  final ApiRoutes? _routes; // optional (backend-enabled)
  final TokenProvider? _tokens; // optional (backend-enabled)

  UserOperationsService._(this._auth, this._client, this._routes, this._tokens);

  /// Firebase-only (no backend calls)
  factory UserOperationsService.firebaseOnly() =>
      UserOperationsService._(FirebaseAuth.instance, null, null, null);

  /// Firebase + backend (tenant-scoped base URL)
  static Future<UserOperationsService> createWithBackend({
    required String tenantId,
    required TokenProvider tokenProvider,
    bool withAuth = true,
  }) async {
    final client = await ApiClient.create(
      tenantId: tenantId,
      tokenProvider: tokenProvider,
      withAuth: withAuth,
    );
    final routes = ApiRoutes(tenantId);
    return UserOperationsService._(
      FirebaseAuth.instance,
      client,
      routes,
      tokenProvider,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────
  Dio get _dio {
    final c = _client?.dio;
    if (c == null) {
      throw StateError(
        'UserOperationsService: backend call requested but service was created without ApiClient/Routes. '
        'Use createWithBackend(...) for backend features.',
      );
    }
    return c;
  }

  T _requireBackend<T>(T? v, String fn) {
    if (v == null) {
      throw StateError(
        'UserOperationsService.$fn requires backend (ApiClient/ApiRoutes/TokenProvider). '
        'Construct with createWithBackend(...).',
      );
    }
    return v;
  }

  String _clean(String? s) => (s ?? '').trim();

  // ─────────────────────────────────────────────────────────────
  // 🔐 Sign In / Sign Out (Firebase client)
  // ─────────────────────────────────────────────────────────────
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = EmailHelper.normalize(email);
    final credential = await _auth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    debugPrint('🔓 Signed in as: ${credential.user?.email}');
    return credential;
  }

  Future<void> signOut() async {
    final email = _auth.currentUser?.email;
    await _auth.signOut();
    debugPrint('🔒 User signed out: $email');
  }

  // ─────────────────────────────────────────────────────────────
  // 🔁 Session / Hydration (Firebase client)
  // ─────────────────────────────────────────────────────────────
  Future<bool> isLoggedIn() async => _auth.currentUser != null;

  Future<void> waitForUser() async {
    final completer = Completer<void>();
    late final StreamSubscription<User?> sub;

    sub = _auth.authStateChanges().listen((user) async {
      debugPrint(
        user != null
            ? '✅ Firebase user restored: ${user.email}'
            : '👻 No Firebase user found',
      );
      if (!completer.isCompleted) completer.complete();
      await sub.cancel();
    });

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => debugPrint('⏳ FirebaseAuth hydration timed out.'),
    );
  }

  Future<void> waitForUserSignIn({
    Duration timeout = const Duration(seconds: 6),
    Duration checkEvery = const Duration(milliseconds: 200),
  }) async {
    final sw = Stopwatch()..start();
    while (_auth.currentUser == null) {
      if (sw.elapsed > timeout) {
        throw TimeoutException(
          '⏰ User not signed in after ${timeout.inSeconds}s',
        );
      }
      await Future.delayed(checkEvery);
    }
    debugPrint('✅ Firebase user ready after ${sw.elapsedMilliseconds}ms');
  }

  // ─────────────────────────────────────────────────────────────
  // 🔑 Tokens + Claims (Firebase client)
  // ─────────────────────────────────────────────────────────────
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('❌ Cannot get token — no user signed in');
      return null;
    }
    final token = await user.getIdToken(forceRefresh);
    debugPrint('🪙 Token fetched (length: ${token!.length})');
    return token;
  }

  Future<void> refreshToken() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('❌ Cannot refresh — no user signed in');
    final token = await user.getIdToken(true);
    debugPrint('🔄 Token force-refreshed (length: ${token!.length})');
  }

  Future<Map<String, dynamic>> getClaims({int retries = 5}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('❌ Firebase Auth token missing');

    for (int i = 0; i < retries; i++) {
      final tokenResult = await user.getIdTokenResult(true);
      final claims = tokenResult.claims ?? {};
      debugPrint('🔐 Attempt ${i + 1} → Claims: $claims');
      if (claims.isNotEmpty) return claims;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    throw Exception('❌ Failed to load Firebase claims after $retries retries');
  }

  Future<void> logClaims() async {
    try {
      final claims = await getClaims();
      debugPrint('🔍 Current user claims: $claims');
    } catch (e) {
      debugPrint('❌ Failed to log claims: $e');
    }
  }

  Future<User?> getCurrentUser() async => _auth.currentUser;

  // ─────────────────────────────────────────────────────────────
  // 🛰️ Backend session ops (tenant-scoped)
  // ─────────────────────────────────────────────────────────────

  /// Check if a user exists / status via backend directory.
  /// Requires service created with backend.
  Future<AuthUser> checkUserStatus({String? email, String? phoneNumber}) async {
    final routes = _requireBackend(_routes, 'checkUserStatus');
    final tokens = _requireBackend(_tokens, 'checkUserStatus');

    final cleanedEmail = _clean(email).toLowerCase();
    final cleanedPhone = _clean(phoneNumber);

    if (cleanedEmail.isEmpty && cleanedPhone.isEmpty) {
      throw ArgumentError('❌ Either email or phoneNumber must be provided');
    }

    final token = await tokens.tryGetToken();
    final uri = routes.checkUserStatus();

    debugPrint('📡 Checking user status: $cleanedEmail / $cleanedPhone');
    debugPrint('🔐 Auth token present: ${token != null}');

    try {
      final response = await _dio.postUri(
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

  /// Convenience wrapper that uses [checkUserStatus].
  Future<bool> isEmailRegistered(String email) async {
    try {
      final user = await checkUserStatus(email: email);
      return user.uid.isNotEmpty;
    } catch (e) {
      debugPrint('❌ isEmailRegistered error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 📧 Password reset (choose path)
  // ─────────────────────────────────────────────────────────────

  /// Send a password reset email.
  /// If [viaBackend] is true and backend is configured, call backend.
  /// Otherwise uses Firebase client SDK directly.
  Future<void> sendPasswordResetEmail(
    String email, {
    ActionCodeSettings? actionCodeSettings,
    bool viaBackend = false,
  }) async {
    final cleanedEmail = EmailHelper.normalize(email);
    if (cleanedEmail.isEmpty) {
      throw ArgumentError('❌ Email is required');
    }

    if (viaBackend) {
      final routes = _requireBackend(
        _routes,
        'sendPasswordResetEmail(viaBackend:true)',
      );
      try {
        final res = await _dio.postUri(
          routes.sendPasswordResetEmail(),
          data: {'email': cleanedEmail},
        );
        if (res.statusCode != 200) {
          final reason = res.data?['error'] ?? 'Unknown error';
          throw Exception('❌ Failed to send reset email: $reason');
        }
        debugPrint('✅ (Backend) Password reset email sent to $cleanedEmail');
        return;
      } catch (e) {
        debugPrint('❌ (Backend) sendPasswordResetEmail failed: $e');
        rethrow;
      }
    }

    // Fallback: Firebase client SDK
    await _auth.sendPasswordResetEmail(
      email: cleanedEmail,
      actionCodeSettings: actionCodeSettings,
    );
    debugPrint('✅ (Client) Password reset email sent to: $cleanedEmail');
  }
}
