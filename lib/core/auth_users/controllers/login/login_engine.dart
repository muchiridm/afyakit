import 'package:afyakit/core/auth_users/extensions/user_status_x.dart';
import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/models/login_outcome.dart';
import 'package:afyakit/core/auth_users/services/auth_session_service.dart';
import 'package:afyakit/core/auth_users/services/login_service.dart';
import 'package:afyakit/shared/types/app_error.dart';
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:dio/dio.dart' show DioException;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final loginEngineProvider = FutureProvider.family
    .autoDispose<LoginEngine, String>((ref, tenantId) async {
      final loginSvc = await ref.read(loginServiceProvider(tenantId).future);
      final session = await ref.read(
        authSessionServiceProvider(tenantId).future,
      );
      return LoginEngine(loginSvc: loginSvc, session: session);
    });

class LoginEngine {
  final LoginService loginSvc; // ⬅️ renamed to avoid clash
  final AuthSessionService session;

  /// Allow INVITED users during explicit invite-accept flow.
  /// For normal login keep false (ACTIVE only).
  final bool allowInvitedForInviteFlow;

  LoginEngine({
    required this.loginSvc,
    required this.session,
    this.allowInvitedForInviteFlow = false,
  });

  // ⛳️ Shim to keep your controller API the same.
  Future<Result<LoginOutcome>> login(String email, String password) =>
      loginWithEmailPassword(email, password);

  Future<Result<LoginOutcome>> loginWithEmailPassword(
    String rawEmail,
    String rawPassword,
  ) async {
    try {
      // ── sanitize ──────────────────────────────────────────────
      final email = EmailHelper.normalize(rawEmail);
      final password = rawPassword.trim();
      if (email.isEmpty || password.isEmpty) {
        return Err(AppError('auth/invalid-input', 'Email & password required'));
      }

      // ── 1) Membership probe (fresh) via SESSION service ───────
      late final AuthUser membership;
      try {
        membership = await session.checkUserStatus(
          email: email,
          useCache: false,
        );
      } on DioException catch (e) {
        final sc = e.response?.statusCode ?? 0;
        if (sc == 404) {
          return Err(
            AppError(
              'auth/not-tenant-member',
              "This account isn't on this tenant.",
            ),
          );
        }
        return Err(AppError('auth/network', 'Network error', cause: e));
      } catch (e) {
        return Err(
          AppError(
            'auth/lookup-failed',
            'Failed to verify membership',
            cause: e,
          ),
        );
      }

      if (membership.status.isDisabled) {
        return Err(
          AppError(
            'auth/user-disabled',
            'This account has been disabled on this tenant.',
          ),
        );
      }

      final isActive = membership.status.isActive;

      // ── 2) Firebase sign-in via LOGIN service ─────────────────
      try {
        debugPrint('🔐 Signing in Firebase user: $email');
        await loginSvc.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        debugPrint('❌ Firebase sign-in error: ${e.code}');
        switch (e.code) {
          case 'user-disabled':
            return Err(
              AppError('auth/user-disabled', 'This account has been disabled.'),
            );
          case 'user-not-found':
          case 'wrong-password':
          case 'invalid-credential':
            return Err(
              AppError('auth/bad-credentials', 'Incorrect email or password.'),
            );
          default:
            return Err(AppError('auth/login-failed', 'Login failed', cause: e));
        }
      }

      await loginSvc.waitForUser();

      // ── 3) Claims (ACTIVE only) via SESSION service ───────────
      final expected = loginSvc.expectedTenantId; // from createWithBackend
      var claimsSynced = false;

      if (isActive && expected != null && expected.isNotEmpty) {
        debugPrint('🧭 Enforcing tenant claim → expected=$expected');
        try {
          await session.ensureTenantClaimSelected(
            expected,
            reason: 'LoginEngine.login',
          );
          claimsSynced = true;
          debugPrint('✅ Tenant claim enforced for $expected');
        } catch (e) {
          debugPrint('❌ Tenant claim enforcement failed: $e');
          final mapped = _mapSyncClaimsError(e);
          final code = mapped?.code;
          if (code == 'auth/membership-not-found' ||
              code == 'auth/user-not-active' ||
              code == 'auth/forbidden' ||
              code == 'auth/wrong-tenant') {
            await loginSvc.signOut();
            return Err(
              mapped ??
                  AppError(
                    'auth/wrong-tenant',
                    'This account does not belong to this tenant.',
                  ),
            );
          }
          // Transient: continue signed-in without claims; SessionEngine/guards will keep you safe.
          debugPrint('⚠️ Proceeding without claims due to transient error.');
        }
      } else if (!isActive) {
        debugPrint('ℹ️ Invited/inactive → limited mode (no claim sync).');
      }

      return Ok(
        LoginOutcome(
          mode: isActive ? LoginMode.active : LoginMode.limited,
          claimsSynced: claimsSynced,
        ),
      );
    } catch (e) {
      debugPrint('❌ Login error: $e');
      return Err(AppError('auth/login-failed', 'Login failed', cause: e));
    }
  }

  Future<Result<void>> sendPasswordReset(String rawEmail) async {
    try {
      final email = EmailHelper.normalize(rawEmail);
      if (!EmailHelper.isValid(email)) {
        return Err(AppError('auth/bad-email', 'Invalid email'));
      }

      // Pre-check existence to give clean UX.
      final isKnown = await loginSvc.isEmailRegistered(email);
      debugPrint('📨 reset precheck(email=$email) → $isKnown');
      if (!isKnown) {
        return Err(AppError('auth/not-registered', 'Email not registered'));
      }

      await loginSvc.sendPasswordResetEmail(email, viaBackend: true);
      return const Ok(null);
    } catch (e) {
      debugPrint('❌ Password reset error: $e');
      return Err(
        AppError('auth/reset-failed', 'Password reset failed', cause: e),
      );
    }
  }

  Future<Result<void>> signOut() async {
    try {
      await loginSvc.signOut();
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/signout-failed', 'Sign out failed', cause: e));
    }
  }

  Future<bool> isSignedIn() async => await loginSvc.isLoggedIn();

  Future<Result<void>> refreshIdToken() async {
    try {
      await loginSvc.getIdToken(forceRefresh: true);
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError('auth/token-refresh-failed', 'Token refresh failed', cause: e),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Private: map backend sync errors to clean UX messages
  // ─────────────────────────────────────────────────────────────
  AppError? _mapSyncClaimsError(Object e) {
    if (e is! DioException) return null;
    final status = e.response?.statusCode ?? 0;
    final data = e.response?.data;
    final code = (data is Map && data['code'] is String)
        ? data['code'] as String
        : null;

    if (status == 403 && code == 'USER_NOT_ACTIVE') {
      return AppError(
        'auth/user-not-active',
        'Your access to this tenant is not active.',
      );
    }
    if (status == 404 && code == 'MEMBERSHIP_NOT_FOUND') {
      return AppError(
        'auth/no-membership',
        'No access to this tenant. Ask an admin to invite you.',
      );
    }
    return null;
  }
}
