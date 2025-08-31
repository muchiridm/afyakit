import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final hqAuthServiceProvider = Provider<HqAuthService>((_) => HqAuthService());

class HqAuthService {
  final fb.FirebaseAuth _auth;
  HqAuthService({fb.FirebaseAuth? auth})
    : _auth = auth ?? fb.FirebaseAuth.instance;

  // Streams & basics
  Stream<fb.User?> get authChanges => _auth.idTokenChanges();
  fb.User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<fb.UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final e = email.trim();
    final cred = await _auth.signInWithEmailAndPassword(
      email: e,
      password: password,
    );
    if (kDebugMode) debugPrint('🔐 [HQ] signed in as: ${cred.user?.email}');
    // Force fresh claims immediately after sign-in
    await cred.user?.getIdTokenResult(true);
    return cred;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  // ── Claims helpers ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getClaims({bool force = true}) async {
    final u = _auth.currentUser;
    if (u == null) return const {};
    final t = await u.getIdTokenResult(force);
    return Map<String, dynamic>.from(t.claims ?? const {});
  }

  Future<bool> hasSuperadmin({bool force = true}) async {
    final claims = await getClaims(force: force);
    return claims['superadmin'] == true;
  }

  /// Simple hydration used on cold start.
  Future<void> waitForUser({
    Duration timeout = const Duration(seconds: 8),
    Duration checkEvery = const Duration(milliseconds: 150),
  }) async {
    final sw = Stopwatch()..start();
    while (_auth.currentUser == null) {
      if (sw.elapsed > timeout) break;
      await Future.delayed(checkEvery);
    }
  }

  // ── Errors ────────────────────────────────────────────────────────────────
  static String friendlyError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential': // web often uses this for bad creds
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is disabled for this project.';
      default:
        return 'Auth error (${e.code}).';
    }
  }

  static String friendlyCode(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is disabled for this project.';
      default:
        return 'Auth error ($code).';
    }
  }
}
