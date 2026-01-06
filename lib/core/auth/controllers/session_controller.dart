// lib/core/auth/controllers/session_controller.dart
//
// NOTE: Keep this in core/auth (not auth_user) because it's session/auth plumbing.
// It returns AuthUser? (tenant-scoped profile), or null for guest.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/core/auth/services/auth_service.dart';
import 'package:afyakit/core/auth_user/models/auth_user_model.dart';

final sessionControllerProvider =
    StateNotifierProvider.family<
      SessionController,
      AsyncValue<AuthUser?>,
      String
    >((ref, tenantId) {
      final ctrl = SessionController(ref, tenantId);
      // Start listening immediately so app reacts to auth changes without manual init loops.
      ctrl._startAuthListener();
      return ctrl;
    });

class SessionController extends StateNotifier<AsyncValue<AuthUser?>> {
  SessionController(this.ref, this.tenantId)
    : super(const AsyncValue.loading());

  final Ref ref;
  final String tenantId;

  StreamSubscription<fb.User?>? _sub;
  bool _initialized = false;

  /// Call once from provider constructor.
  void _startAuthListener() {
    _sub?.cancel();

    // idTokenChanges fires on:
    // - sign in / sign out
    // - token refresh (claims changes)
    _sub = fb.FirebaseAuth.instance.idTokenChanges().listen(
      (fbUser) async {
        await _syncFromFirebaseUser(fbUser);
      },
      onError: (Object err, StackTrace st) {
        // Don't brick the app; just log + treat as guest.
        state = const AsyncValue.data(null);
      },
    );

    // Kick an initial sync right away (don't wait for first stream emission).
    unawaited(_syncFromFirebaseUser(fb.FirebaseAuth.instance.currentUser));
  }

  Future<void> _syncFromFirebaseUser(fb.User? fbUser) async {
    // First run: show loading. After that, avoid flickering loading on refresh.
    if (!_initialized) {
      _initialized = true;
      state = const AsyncValue.loading();
    }

    // Guest
    if (fbUser == null) {
      state = const AsyncValue.data(null);
      return;
    }

    try {
      final svc = await ref.read(authServiceProvider(tenantId).future);

      // Prefer cached user if already loaded for this tenant
      final cached = svc.currentUser;
      if (cached != null) {
        state = AsyncValue.data(cached);
        return;
      }

      // Otherwise fetch session from backend
      final user = await svc.loadSession();
      state = AsyncValue.data(user);
    } catch (err, st) {
      // IMPORTANT: if session fetch fails, do NOT force-login.
      // Keep app usable (staff home can still show) and allow retry.
      state = AsyncValue.error(err, st);
    }
  }

  /// Keep the API for callers that explicitly want to trigger refresh,
  /// but it should rarely be needed now.
  Future<void> init() async {
    // With the auth listener, init just forces a resync.
    await _syncFromFirebaseUser(fb.FirebaseAuth.instance.currentUser);
  }

  /// Centralised OTP sign-in:
  /// - verifies OTP via backend (optionally with email)
  /// - signs in Firebase
  /// - loads session and updates state
  Future<void> signInWithOtp({
    required String phoneE164,
    required String code,
    String? attemptId,
    String? email,
  }) async {
    state = const AsyncValue.loading();

    try {
      final svc = await ref.read(authServiceProvider(tenantId).future);

      await svc.verifyOtp(
        phoneE164: phoneE164,
        code: code,
        attemptId: attemptId,
        email: email,
      );

      // After verifyOtp, Firebase user should exist; load tenant session.
      final user = svc.currentUser ?? await svc.loadSession();
      state = AsyncValue.data(user);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  Future<void> logOut() async {
    try {
      final svc = await ref.read(authServiceProvider(tenantId).future);
      await svc.logOut();
    } finally {
      // Whether backend logout succeeds or not, clear local state.
      state = const AsyncValue.data(null);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}
