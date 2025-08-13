import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:afyakit/shared/utils/normalize/normalize_email.dart';

final firebaseAuthServiceProvider = Provider<FirebaseAuthService>(
  (ref) => FirebaseAuthService(),
);

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─────────────────────────────────────────────────────────────
  // 🔐 Sign In / Reset / Sign Out
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

  Future<void> sendPasswordResetEmail(
    String email, {
    ActionCodeSettings? actionCodeSettings,
  }) async {
    final normalizedEmail = EmailHelper.normalize(email);
    await _auth.sendPasswordResetEmail(
      email: normalizedEmail,
      actionCodeSettings: actionCodeSettings,
    );
    debugPrint('📧 Password reset email sent to: $normalizedEmail');
  }

  Future<void> signOut() async {
    final email = _auth.currentUser?.email;
    await _auth.signOut();
    debugPrint('🔒 User signed out: $email');
  }

  // ─────────────────────────────────────────────────────────────
  // 🔁 Session / Hydration
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

      if (!completer.isCompleted) {
        completer.complete();
      }

      await sub.cancel();
    });

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('⏳ FirebaseAuth hydration timed out.');
      },
    );
  }

  Future<void> waitForUserSignIn({
    Duration timeout = const Duration(seconds: 6),
    Duration checkEvery = const Duration(milliseconds: 200),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (_auth.currentUser == null) {
      if (stopwatch.elapsed > timeout) {
        throw TimeoutException(
          '⏰ User not signed in after ${timeout.inSeconds}s',
        );
      }
      await Future.delayed(checkEvery);
    }

    debugPrint(
      '✅ Firebase user ready after ${stopwatch.elapsedMilliseconds}ms',
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 🔑 Tokens + Claims
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

  // ─────────────────────────────────────────────────────────────
  // 🧪 User Access
  // ─────────────────────────────────────────────────────────────

  Future<User?> getCurrentUser() async => _auth.currentUser;
}
