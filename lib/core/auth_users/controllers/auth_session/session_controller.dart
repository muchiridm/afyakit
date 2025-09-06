import 'dart:async';
import 'package:afyakit/app/afyakit_app.dart';
import 'package:afyakit/core/auth_users/extensions/user_status_x.dart';
import 'package:afyakit/shared/utils/dev_trace.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/dev/dev_auth_manager.dart';
import 'package:afyakit/core/auth_users/widgets/auth_gate.dart';

import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/shared/types/result.dart';

import 'package:afyakit/core/auth_users/controllers/auth_session/session_engine.dart';

final sessionControllerProvider =
    StateNotifierProviderFamily<
      SessionController,
      AsyncValue<AuthUser?>,
      String
    >((ref, tenantId) => SessionController(ref: ref, tenantId: tenantId));

class SessionController extends StateNotifier<AsyncValue<AuthUser?>> {
  final Ref ref;
  final String tenantId;

  SessionEngine? _engine;
  Completer<void>? _initCompleter;
  bool _sessionInitialized = false;

  SessionController({required this.ref, required this.tenantId})
    : super(const AsyncLoading());

  // ─────────────────────────────────────────────
  // 🚦 Public Lifecycle
  // ─────────────────────────────────────────────

  Future<void> ensureReady() {
    final t = DevTrace('session.ensureReady');
    _initCompleter ??= Completer<void>();
    if (_sessionInitialized) {
      t.done('already-initialized');
      return _initCompleter!.future;
    }

    _sessionInitialized = true;
    t.log('initialize');
    _initialize()
        .then((_) {
          t.done('ok');
          _initCompleter?.complete();
        })
        .catchError((e, st) {
          t.done('error: $e');
          _initCompleter?.completeError(e, st);
        });

    return _initCompleter!.future;
  }

  Future<void> reload({bool forceRefresh = false}) async {
    // Don’t ever sign-out here.
    await ensureReady(); // warm the engine if needed
    if (_engine == null) return;

    // Prefer a soft path: refresh ID token + re-fetch backend user.
    final res = await _engine!
        .refreshTokenAndClaimsAndUser(); // implement this as: getIdToken(true) + GET /me
    _applyResult('Failed to reload session', res);
  }

  void reset() => state = const AsyncValue.data(null);

  // ─────────────────────────────────────────────
  // 🔐 Initialization (engine-only)
  // ─────────────────────────────────────────────
  Future<void> _initialize() async {
    debugPrint('🚀 Initializing AuthSessionController for tenant: $tenantId');

    try {
      _engine ??= await ref.read(sessionEngineProvider(tenantId).future);

      // Let the engine drive the whole flow (hydration + claims sync + backend load)
      var res = await _engine!.ensureReady();

      // Not signed-in? In debug, try the dev user once, then re-run engine.
      if (res is Ok<AuthUser?> && (res).value == null) {
        if (kDebugMode && await _tryDevFallback()) {
          res = await _engine!.ensureReady();
          _applyResult('Session initialization failed after dev fallback', res);
          return;
        }
      }

      _applyResult('Session initialization failed', res);
    } catch (e, st) {
      _handleFatal('Session initialization failed', e, st);
      reset();
    }
  }

  // ─────────────────────────────────────────────
  // 🧪 Dev Fallback (engine-only)
  // ─────────────────────────────────────────────
  Future<bool> _tryDevFallback() async {
    debugPrint('🧪 Trying dev fallback sign-in...');
    final result = await DevAuthManager.maybeSignInDevUser(ref: ref);

    // Re-run engine to hydrate/verify after dev sign-in
    final res = await _engine!.ensureReady();
    final auth = (res is Ok<AuthUser?>) ? res.value : null;
    final signedIn = auth != null;

    if (!signedIn) return false;

    // If claims didn't sync, only consider warning for ACTIVE users.
    if (!result.claimsSynced && (auth.status.isActive)) {
      // No snack: this is usually transient; we'll just log and move on.
      debugPrint(
        'ℹ️ Dev fallback: active user but claims not yet synced (will settle).',
      );
      // Optionally kick a silent refresh in the background:
      // unawaited(_engine!.reload());
    }

    return true;
  }

  // ─────────────────────────────────────────────
  // 📦 Helpers
  // ─────────────────────────────────────────────
  void _applyResult(String ctx, Result<AuthUser?> res) {
    if (res is Ok<AuthUser?>) {
      state = AsyncValue<AuthUser?>.data(res.value);
      return;
    }
    final err = (res as Err<AuthUser?>).error;

    if (err.code == 'auth/membership-not-found' ||
        err.code == 'auth/user-not-active') {
      debugPrint('ℹ️ $ctx → ${err.code}. Showing Login for this workspace.');
    } else {
      debugPrint('❌ $ctx: ${err.code} - ${err.message} | cause: ${err.cause}');
    }
    state = const AsyncValue<AuthUser?>.data(null);
  }

  void _handleFatal(String context, Object error, StackTrace st) {
    debugPrint('❌ $context: $error');
    state = AsyncValue<AuthUser?>.error(context, st);
  }

  /// Clean the magic-link / oobCode clutter from URL after password reset actions.
  void cleanUrl() {
    if (Uri.base.queryParameters.containsKey('oobCode')) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    }
  }

  // ─────────────────────────────────────────────
  // 🧩 Public Getters
  // ─────────────────────────────────────────────
  String? get uid => state.value?.uid;
  AuthUser? get currentUser => state.value;
}
