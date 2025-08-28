import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/shared/services/snack_service.dart';

final hqLoginControllerProvider =
    StateNotifierProvider.autoDispose<HqLoginController, HqLoginState>(
      (ref) => HqLoginController(ref),
    );

// ─────────────────────────────────────────────

class HqLoginState {
  final bool isLoading;
  final String? error;
  final String? email;
  final bool isSuperAdmin;

  const HqLoginState({
    this.isLoading = false,
    this.error,
    this.email,
    this.isSuperAdmin = false,
  });

  HqLoginState copyWith({
    bool? isLoading,
    String? error, // '' clears
    String? email,
    bool? isSuperAdmin,
  }) {
    return HqLoginState(
      isLoading: isLoading ?? this.isLoading,
      error: (error == '') ? null : (error ?? this.error),
      email: email ?? this.email,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
    );
  }
}

// ─────────────────────────────────────────────

class HqLoginController extends StateNotifier<HqLoginState> {
  HqLoginController(this.ref) : super(const HqLoginState());
  final Ref ref;

  fb.FirebaseAuth get _auth => fb.FirebaseAuth.instance;

  Future<void> signIn({required String email, required String password}) async {
    final e = email.trim();
    state = state.copyWith(isLoading: true, error: '', email: e);

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: e,
        password: password,
      );

      // Force fresh ID token so the gate sees updated claims immediately.
      final token = await cred.user?.getIdTokenResult(true);
      final claims = token?.claims ?? const <String, dynamic>{};
      final isSuper = claims['superadmin'] == true;

      if (kDebugMode) {
        debugPrint(
          '🔐 [HQ login] uid=${cred.user?.uid} email=${cred.user?.email} '
          'super=$isSuper claims=$claims',
        );
      }

      if (!mounted) return; // screen probably unmounted → bail out
      state = state.copyWith(isLoading: false, isSuperAdmin: isSuper);
      SnackService.showSuccess('Welcome back');
    } on fb.FirebaseAuthException catch (ex) {
      final msg = _friendlyError(ex);
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: msg);
      SnackService.showError(msg);
    } catch (ex, st) {
      if (kDebugMode) debugPrint('🧨 signIn error: $ex\n$st');
      if (!mounted) return;
      final msg = 'Sign-in failed: $ex';
      state = state.copyWith(isLoading: false, error: msg);
      SnackService.showError(msg);
    }
  }

  Future<void> resetPassword(String email) async {
    final e = email.trim();
    if (e.isEmpty) {
      final msg = 'Enter your email first to reset the password.';
      if (!mounted) return;
      state = state.copyWith(error: msg);
      SnackService.showError(msg);
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: e);
      if (!mounted) return;
      SnackService.showSuccess('Password reset email sent to $e');
    } on fb.FirebaseAuthException catch (ex) {
      final msg = _friendlyError(ex);
      if (!mounted) return;
      state = state.copyWith(error: msg);
      SnackService.showError(msg);
    } catch (ex) {
      if (!mounted) return;
      final msg = 'Failed to send reset email: $ex';
      state = state.copyWith(error: msg);
      SnackService.showError(msg);
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      state = const HqLoginState();
      SnackService.showSuccess('Signed out');
    } catch (ex) {
      if (!mounted) return;
      final msg = 'Failed to sign out: $ex';
      state = state.copyWith(error: msg);
      SnackService.showError(msg);
    }
  }

  Future<void> refreshClaims() async {
    final u = _auth.currentUser;
    if (u == null) return;
    try {
      final t = await u.getIdTokenResult(true);
      final claims = t.claims ?? const <String, dynamic>{};
      final isSuper = claims['superadmin'] == true;
      if (kDebugMode) {
        debugPrint('🧾 [HQ login] refreshed claims: super=$isSuper, $claims');
      }
      if (!mounted) return;
      state = state.copyWith(isSuperAdmin: isSuper);
    } catch (ex) {
      if (kDebugMode) debugPrint('🧾 refreshClaims failed: $ex');
      // no state write if disposed
    }
  }

  String _friendlyError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'This account is not registered.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Auth error (${e.code}).';
    }
  }
}
