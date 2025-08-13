// 📂 lib/users/controllers/auth_session_controller.dart

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/dev/dev_auth_manager.dart';
import 'package:afyakit/main.dart';
import 'package:afyakit/users/widgets/auth_gate.dart';
import 'package:afyakit/users/services/firebase_auth_service.dart';
import 'package:afyakit/users/services/user_session_service.dart';
import 'package:afyakit/users/models/auth_user.dart';
import 'package:afyakit/users/utils/claim_validator.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:afyakit/shared/providers/api_client_provider.dart';

final userSessionControllerProvider =
    StateNotifierProviderFamily<
      UserSessionController,
      AsyncValue<AuthUser?>,
      String
    >((ref, tenantId) {
      return UserSessionController(
        ref: ref,
        tenantId: tenantId,
        auth: ref.read(firebaseAuthServiceProvider),
      );
    });

class UserSessionController extends StateNotifier<AsyncValue<AuthUser?>> {
  final Ref ref;
  final String tenantId;
  final FirebaseAuthService auth;

  UserSessionService? _sessionService;
  Completer<void>? _initCompleter;
  bool _sessionInitialized = false;

  UserSessionController({
    required this.ref,
    required this.tenantId,
    required this.auth,
  }) : super(const AsyncLoading());

  // ─────────────────────────────────────────────
  // 🚦 Public Lifecycle
  // ─────────────────────────────────────────────

  Future<void> ensureReady() {
    _initCompleter ??= Completer<void>();
    if (_sessionInitialized) return _initCompleter!.future;

    _sessionInitialized = true;
    _initializeSession()
        .then((_) => _initCompleter?.complete())
        .catchError((e, st) => _initCompleter?.completeError(e, st));

    return _initCompleter!.future;
  }

  Future<void> reload({bool forceRefresh = false}) async {
    if (forceRefresh) _sessionInitialized = false;
    await ensureReady();
    await _loadCurrentUser();
  }

  void reset() => state = const AsyncValue.data(null);

  // ─────────────────────────────────────────────
  // 🔐 Initialization Logic
  // ─────────────────────────────────────────────

  Future<void> _initializeSession() async {
    debugPrint('🚀 Initializing AuthSessionController');

    try {
      await auth.waitForUser();
      var firebaseUser = await _getCurrentFirebaseUser();

      if (firebaseUser == null) {
        if (kDebugMode && await _tryDevFallback()) {
          firebaseUser = await _getCurrentFirebaseUser();
        } else {
          debugPrint('⚠️ No Firebase user and not in debug mode. Bailing.');
          reset();
          return;
        }
      }

      await _syncClaimsIfMissing();
      await _loadCurrentUser(firebaseUser);
    } catch (e, st) {
      _handleError('Session initialization failed', e, st);
      reset();
    }
  }

  Future<void> _loadCurrentUser([User? cachedUser]) async {
    try {
      final firebaseUser = cachedUser ?? await _getCurrentFirebaseUser();
      final email = firebaseUser?.email?.trim().toLowerCase() ?? '';
      if (email.isEmpty) throw Exception('❌ No Firebase email');

      debugPrint('✅ Firebase user found: $email');

      final service = await _getSessionService();
      final authUser = await service.checkUserStatus(email: email);

      debugPrint('✅ AuthUser loaded: ${authUser.email} (${authUser.status})');
      state = AsyncValue.data(authUser);
    } catch (e, st) {
      _handleError('Failed to load AuthUser', e, st);
      reset();
    }
  }

  // ─────────────────────────────────────────────
  // 🔄 Claims Sync
  // ─────────────────────────────────────────────

  Future<void> _syncClaimsIfMissing() async {
    debugPrint('🔄 Checking/syncing claims...');
    await auth.refreshToken();

    final firebaseUser = await _retry(
      () => auth.getCurrentUser(),
      until: (u) => u != null,
    );
    if (firebaseUser == null) throw Exception('❌ No Firebase user');

    final claims = await auth.getClaims();
    if (ClaimValidator.isValid(claims)) return;

    debugPrint('⚠️ Claims missing. Triggering backend sync...');
    try {
      final service = await _getSessionService();
      await service.checkUserStatus(email: firebaseUser.email);
    } catch (e) {
      debugPrint('⚠️ Backend sync failed: $e');
    }

    final syncedClaims = await _retry(
      () => auth.getClaims(),
      until: ClaimValidator.isValid,
    );
    if (syncedClaims == null) throw Exception('❌ Invalid claims after sync');

    debugPrint('🧾 Final claims: $syncedClaims');
  }

  // ─────────────────────────────────────────────
  // 🧪 Dev Fallback
  // ─────────────────────────────────────────────

  Future<bool> _tryDevFallback() async {
    debugPrint('🧪 Trying dev fallback...');
    final result = await DevAuthManager.maybeSignInDevUser(ref: ref);
    final user = await auth.getCurrentUser();
    if (user == null) return false;

    if (!result.claimsSynced) {
      SnackService.showError('Signed in, but claims not synced.');
    }
    return true;
  }

  // ─────────────────────────────────────────────
  // 📦 Helpers
  // ─────────────────────────────────────────────

  Future<User?> _getCurrentFirebaseUser() async => await auth.getCurrentUser();

  Future<UserSessionService> _getSessionService() async {
    if (_sessionService != null) return _sessionService!;

    final tokenProviderInstance = ref.read(tokenProvider);
    final token = await tokenProviderInstance.getToken();
    if (token.isEmpty) throw Exception('❌ Token is empty.');

    final client = await ref.read(apiClientProvider.future);
    _sessionService = UserSessionService(
      client: client,
      routes: ApiRoutes(tenantId),
      tokenProvider: tokenProviderInstance,
    );
    return _sessionService!;
  }

  Future<T?> _retry<T>(
    Future<T?> Function() task, {
    int retries = 5,
    Duration delay = const Duration(milliseconds: 400),
    bool Function(T?)? until,
  }) async {
    for (int i = 0; i < retries; i++) {
      final result = await task();
      if (until == null || until(result)) return result;
      await Future.delayed(delay * (i + 1));
    }
    return null;
  }

  void _handleError(String context, Object error, StackTrace st) {
    debugPrint('❌ $context: $error');
    state = AsyncValue.error(context, st);
  }

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
