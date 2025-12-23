import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final hqAuthServiceProvider = Provider<HqAuthService>((_) => HqAuthService());

class HqAuthService {
  final fb.FirebaseAuth _auth;

  HqAuthService({fb.FirebaseAuth? auth})
    : _auth = auth ?? fb.FirebaseAuth.instance;

  // ────────────────────────────────────────────────────────────
  // Streams & basics
  // ────────────────────────────────────────────────────────────

  Stream<fb.User?> get authChanges => _auth.idTokenChanges();
  fb.User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;

  // ────────────────────────────────────────────────────────────
  // Actions
  // ────────────────────────────────────────────────────────────

  /// HQ now uses the shared OTP login flow (phone + email OTP).
  /// This service only handles claims and sign-out.
  Future<void> signOut() => _auth.signOut();

  // ────────────────────────────────────────────────────────────
  // Claims helpers
  // ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getClaims({bool force = true}) async {
    final u = _auth.currentUser;
    if (u == null) return const {};
    final t = await u.getIdTokenResult(force);
    return Map<String, dynamic>.from(t.claims ?? const {});
  }

  /// Returns true if the current user has superadmin claims.
  ///
  /// This only checks Firebase custom claims:
  ///   - `superadmin: true` or
  ///   - `isSuperAdmin: true`
  ///
  /// No dev-email shortcuts, no local overrides.
  Future<bool> hasSuperadmin({bool force = true}) async {
    final claims = await getClaims(force: force);
    final isSuper =
        claims['isSuperAdmin'] == true || claims['superadmin'] == true;

    if (kDebugMode) {
      debugPrint('🔐 [HQ] superadmin=$isSuper claims=$claims');
    }
    return isSuper;
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

  // ────────────────────────────────────────────────────────────
  // Error helpers
  // ────────────────────────────────────────────────────────────

  static String friendlyError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential': // often used as "bad creds"
        return 'Incorrect credentials.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'operation-not-allowed':
        return 'This sign-in method is disabled for this project.';
      default:
        return 'Auth error (${e.code}).';
    }
  }

  static String friendlyCode(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect credentials.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'operation-not-allowed':
        return 'This sign-in method is disabled for this project.';
      default:
        return 'Auth error ($code).';
    }
  }
}
