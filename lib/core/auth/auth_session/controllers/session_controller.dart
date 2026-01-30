// lib/core/auth/controllers/session_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/core/auth/auth_session/services/auth_service.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

final sessionControllerProvider =
    StateNotifierProvider.family<
      SessionController,
      AsyncValue<AuthUser?>,
      String
    >((ref, tenantId) => SessionController(ref, tenantId));

class SessionController extends StateNotifier<AsyncValue<AuthUser?>> {
  SessionController(this.ref, this.tenantId)
    : super(const AsyncValue.loading()) {
    _startAuthListener();
  }

  final Ref ref;
  final String tenantId;

  StreamSubscription<fb.User?>? _sub;
  bool _initialized = false;

  void _startAuthListener() {
    _sub?.cancel();

    _sub = fb.FirebaseAuth.instance.idTokenChanges().listen(
      (fbUser) async {
        // Token changed, but that doesn't always mean our backend session doc changed.
        // We still allow caching here for performance.
        await _syncFromFirebaseUser(fbUser, forceNetwork: false);
      },
      onError: (Object err, StackTrace st) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ [session] idTokenChanges error (treating as guest): $err',
          );
        }
        state = const AsyncValue.data(null);
      },
    );

    unawaited(
      _syncFromFirebaseUser(
        fb.FirebaseAuth.instance.currentUser,
        forceNetwork: false,
        showLoadingIfNeeded: true,
      ),
    );
  }

  Future<void> _syncFromFirebaseUser(
    fb.User? fbUser, {
    required bool forceNetwork,
    bool showLoadingIfNeeded = false,
  }) async {
    // Only show loading on first init (or when explicitly requested)
    if (!_initialized) {
      _initialized = true;
      state = const AsyncValue.loading();
    } else if (showLoadingIfNeeded) {
      // Optional hook if you ever want to show loading for explicit calls
      state = const AsyncValue.loading();
    }

    if (fbUser == null) {
      state = const AsyncValue.data(null);
      return;
    }

    final previousUser = state.valueOrNull;

    try {
      final svc = await ref.read(authServiceProvider(tenantId).future);

      // ✅ Use cache ONLY when not forcing network.
      final cached = svc.currentUser;
      if (!forceNetwork && cached != null && cached.uid == fbUser.uid) {
        state = AsyncValue.data(cached);
        return;
      }

      // ✅ Source of truth
      final fresh = await svc.loadSession();
      state = AsyncValue.data(fresh);
    } catch (err, st) {
      // Keep previous session user if we had one (better UX during network wobble)
      if (previousUser != null) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ [session] loadSession failed; keeping previous user: $err',
          );
        }
        state = AsyncValue.data(previousUser);
        return;
      }

      state = AsyncValue.error(err, st);
    }
  }

  /// Force a backend session reload (ignores AuthService cache).
  Future<void> refresh({bool forceNetwork = true}) async {
    await _syncFromFirebaseUser(
      fb.FirebaseAuth.instance.currentUser,
      forceNetwork: forceNetwork,
      showLoadingIfNeeded: false,
    );
  }

  /// Centralised OTP sign-in (tenant-scoped).
  Future<void> signInWithOtp({
    required String attemptId,
    required String code,
    String? firstName,
    String? lastName,
    String? companyName,
  }) async {
    state = const AsyncValue.loading();
    _initialized = true;

    try {
      final svc = await ref.read(authServiceProvider(tenantId).future);

      await svc.verifyOtpAndSignIn(
        attemptId: attemptId,
        code: code,
        firstName: firstName,
        lastName: lastName,
        companyName: companyName,
      );

      // ✅ After any auth event, force network session reload
      await refresh(forceNetwork: true);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  Future<void> signInWithCustomToken(String customToken) async {
    state = const AsyncValue.loading();
    _initialized = true;

    try {
      final svc = await ref.read(authServiceProvider(tenantId).future);

      await svc.signInWithCustomToken(customToken);

      // ✅ CRITICAL: email verification updates backend user doc;
      // do NOT rely on svc.currentUser cache here.
      await refresh(forceNetwork: true);
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
