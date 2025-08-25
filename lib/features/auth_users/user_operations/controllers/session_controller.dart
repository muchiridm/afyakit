// lib/users/controllers/auth_session_controller.dart
import 'dart:async';
import 'package:afyakit/features/auth_users/providers/user_operations_engine_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/dev/dev_auth_manager.dart';
import 'package:afyakit/main.dart';
import 'package:afyakit/features/auth_users/widgets/auth_gate.dart';

import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/features/auth_users/models/auth_user_model.dart';
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/types/app_error.dart';

// Engines & providers
import 'package:afyakit/features/auth_users/user_operations/engines/session_engine.dart';
// ^ If your file is named differently (e.g. user_operations_engine_providers.dart),
//   change the import to match your project.

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
    _initCompleter ??= Completer<void>();
    if (_sessionInitialized) return _initCompleter!.future;

    _sessionInitialized = true;
    _initialize()
        .then((_) => _initCompleter?.complete())
        .catchError((e, st) => _initCompleter?.completeError(e, st));

    return _initCompleter!.future;
  }

  Future<void> reload({bool forceRefresh = false}) async {
    if (forceRefresh) _sessionInitialized = false;
    await ensureReady();
    if (_engine == null) return;
    final res = await _engine!.reload();
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
    final signedIn = res is Ok<AuthUser?> && res.value != null;

    if (!signedIn) return false;
    if (!result.claimsSynced) {
      SnackService.showError('Signed in, but claims not synced.');
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
    _handleNonFatal(ctx, err);
    state = const AsyncValue<AuthUser?>.data(null);
  }

  void _handleNonFatal(String context, AppError error) {
    debugPrint(
      '❌ $context: ${error.code} - ${error.message} | cause: ${error.cause}',
    );
    // Keep UI chill; just set state/null and optionally toast in calling sites if needed.
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
