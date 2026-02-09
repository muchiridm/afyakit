// lib/core/auth/auth_session/controllers/session_controller.dart

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

  /// Track last successful backend session fetch (per controller/tenant)
  DateTime? _lastNetworkFetchAt;

  /// Cache TTL: allow fast refreshes without spamming backend, but never indefinitely
  static const Duration _sessionCacheTtl = Duration(seconds: 30);

  Future<AuthService> _svc() async =>
      ref.read(authServiceProvider(tenantId).future);

  void _startAuthListener() {
    _sub?.cancel();

    _sub = fb.FirebaseAuth.instance.idTokenChanges().listen(
      (fbUser) async {
        // Background refresh (no loading flicker).
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
      'phoneClaimed=${u?.phoneClaimed} '
      'phoneSatisfied=${u?.phoneSatisfied} '
      'emailVerified=${u?.emailVerified} '
      'emailLower="${u?.emailLower}" '
      'isCompany=${u?.isCompany} '
      'firstName="${u?.firstName}" lastName="${u?.lastName}" company="${u?.companyName}"',
    );
  }

  bool _cacheStillFresh() {
    final t = _lastNetworkFetchAt;
    if (t == null) return false;
    return DateTime.now().difference(t) <= _sessionCacheTtl;
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

      // ✅ Cache fast-path, but ONLY if:
      // - not forcing network
      // - cached matches uid
      // - AND last backend fetch is still within TTL
      final cached = svc.currentUser;
      if (!forceNetwork &&
          _cacheStillFresh() &&
          cached != null &&
          cached.uid == fbUser.uid) {
        if (_disposed) return;
        state = AsyncValue.data(cached);
        _logSessionUser(cached, where: 'cache');
        return;
      }

      // Source of truth: backend session (AUTH REQUIRED)
      final fresh = await svc.loadSession();
      _lastNetworkFetchAt = DateTime.now();

      if (_disposed) return;
      state = AsyncValue.data(fresh);
      _logSessionUser(fresh, where: 'network');
    } catch (err, st) {
      if (_shouldTreatAsGuestError(err)) {
        _logSessionError(err, st, where: 'loadSession');

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
      _lastNetworkFetchAt = null;
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

      _lastNetworkFetchAt = null;
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
      _lastNetworkFetchAt = null;
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
