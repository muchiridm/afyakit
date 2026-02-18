import 'dart:async';

import 'package:dio/dio.dart';
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
  bool _disposed = false;

  /// Prevent duplicate concurrent loadSession calls
  Future<void>? _inflight;

  Future<AuthService> _svc() async =>
      ref.read(authServiceProvider(tenantId).future);

  void _startAuthListener() {
    _sub?.cancel();

    _sub = fb.FirebaseAuth.instance.idTokenChanges().listen(
      (fbUser) async {
        // Background refresh (no loading flicker).
        // NOTE: this is not forced network, but we now use a "safe cache" check.
        await _syncFromFirebaseUser(
          fbUser,
          forceNetwork: false,
          showLoadingIfNeeded: false,
        );
      },
      onError: (Object err, StackTrace st) {
        if (kDebugMode) {
          debugPrint('⚠️ [session] idTokenChanges error: $err');
        }
        if (_disposed) return;
        state = const AsyncValue.data(null);
      },
    );

    // Prime on startup (show loading once if first boot)
    unawaited(
      _syncFromFirebaseUser(
        fb.FirebaseAuth.instance.currentUser,
        forceNetwork: false,
        showLoadingIfNeeded: true,
      ),
    );
  }

  void _setLoadingIfNeeded({required bool showLoadingIfNeeded}) {
    if (_disposed) return;

    if (!_initialized) {
      _initialized = true;
      state = const AsyncValue.loading();
      return;
    }

    if (showLoadingIfNeeded) {
      state = const AsyncValue.loading();
    }
  }

  bool _shouldTreatAsGuestError(Object err) {
    // Backend session endpoint should return 401/403 when not signed in.
    // Some deployments incorrectly throw 500 on missing/invalid token.
    if (err is DioException) {
      final code = err.response?.statusCode;
      return code == 401 || code == 403 || code == 500;
    }
    return false;
  }

  void _logSessionError(Object err, StackTrace st, {required String where}) {
    if (!kDebugMode) return;

    if (err is DioException) {
      debugPrint(
        '⚠️ [session] $where failed (HTTP ${err.response?.statusCode}) '
        'url=${err.requestOptions.uri} '
        'body=${err.response?.data}',
      );
      return;
    }

    debugPrint('⚠️ [session] $where failed: $err');
  }

  void _logSessionUser(AuthUser? u, {required String where}) {
    if (!kDebugMode) return;
    debugPrint(
      '🧾 [session][$where] uid=${u?.uid} '
      'phoneVerified=${u?.phoneVerified} '
      'emailVerified=${u?.emailVerified} '
      'isCompany=${u?.isCompany} '
      'firstName="${u?.firstName}" lastName="${u?.lastName}" company="${u?.companyName}"',
    );
  }

  bool _sameCriticalFlags(AuthUser? a, AuthUser? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.uid != b.uid) return false;

    // These are the gating fields that decide whether you see the email screen.
    return a.phoneVerified == b.phoneVerified &&
        a.phoneClaimed == b.phoneClaimed &&
        a.emailVerified == b.emailVerified;
  }

  Future<void> _syncFromFirebaseUser(
    fb.User? fbUser, {
    required bool forceNetwork,
    required bool showLoadingIfNeeded,
  }) async {
    if (_disposed) return;

    _inflight ??=
        _syncInternal(
          fbUser,
          forceNetwork: forceNetwork,
          showLoadingIfNeeded: showLoadingIfNeeded,
        ).whenComplete(() {
          _inflight = null;
        });

    return _inflight!;
  }

  Future<void> _syncInternal(
    fb.User? fbUser, {
    required bool forceNetwork,
    required bool showLoadingIfNeeded,
  }) async {
    if (_disposed) return;

    _setLoadingIfNeeded(showLoadingIfNeeded: showLoadingIfNeeded);

    // If Firebase has no user, we are a guest.
    if (fbUser == null) {
      if (_disposed) return;
      state = const AsyncValue.data(null);
      return;
    }

    final previousUser = state.valueOrNull;

    try {
      final svc = await _svc();

      // Prime a fresh Firebase idToken BEFORE calling backend.
      try {
        await fbUser.getIdToken(true);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [session] getIdToken(true) failed (continuing): $e');
        }
      }

      // ✅ SAFE cache fast-path:
      // Only reuse cached user if it matches the CURRENT state's critical flags.
      // Otherwise fetch from backend to avoid hiding updates to phoneVerified/emailVerified.
      final cached = svc.currentUser;
      if (!forceNetwork && cached != null && cached.uid == fbUser.uid) {
        if (_sameCriticalFlags(cached, previousUser)) {
          if (_disposed) return;
          state = AsyncValue.data(cached);
          _logSessionUser(cached, where: 'cache');
          return;
        }
        // Cached exists but looks stale relative to current gating flags.
        // Fall through to backend loadSession().
      }

      // Source of truth: backend session (AUTH REQUIRED)
      final fresh = await svc.loadSession();
      if (_disposed) return;
      state = AsyncValue.data(fresh);
      _logSessionUser(fresh, where: 'network');
    } catch (err, st) {
      if (_shouldTreatAsGuestError(err)) {
        _logSessionError(err, st, where: 'loadSession');

        // Keep previous user to reduce flicker on transient failures.
        if (_disposed) return;
        state = previousUser != null
            ? AsyncValue.data(previousUser)
            : const AsyncValue.data(null);
        return;
      }

      _logSessionError(err, st, where: 'loadSession');

      if (_disposed) return;

      if (previousUser != null) {
        state = AsyncValue.data(previousUser);
        return;
      }

      state = AsyncValue.error(err, st);
    }
  }

  /// Force a backend session reload.
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
    if (_disposed) return;

    state = const AsyncValue.loading();
    _initialized = true;

    try {
      final svc = await _svc();

      await svc.verifyOtpAndSignIn(
        attemptId: attemptId,
        code: code,
        firstName: firstName,
        lastName: lastName,
        companyName: companyName,
      );

      // After auth event, force network session reload
      await refresh(forceNetwork: true);
    } catch (err, st) {
      if (_disposed) return;
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  Future<void> signInWithCustomToken(String customToken) async {
    if (_disposed) return;

    state = const AsyncValue.loading();
    _initialized = true;

    try {
      final svc = await _svc();

      await svc.signInWithCustomToken(customToken);

      // Force fresh idToken immediately
      final fbUser = fb.FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        try {
          await fbUser.getIdToken(true);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ [session] post-signIn getIdToken(true) failed: $e');
          }
        }
      }

      await refresh(forceNetwork: true);
    } catch (err, st) {
      if (_disposed) return;
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  Future<void> logOut() async {
    try {
      final svc = await _svc();
      await svc.logOut();
    } finally {
      if (_disposed) return;
      state = const AsyncValue.data(null);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}
