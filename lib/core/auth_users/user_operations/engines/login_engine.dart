// lib/core/auth_users/user_operations/engines/login_engine.dart
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/types/app_error.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:afyakit/core/auth_users/services/user_operations_service.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart' show DioException;

class LoginOutcome {
  final bool registered;
  final bool signedIn;
  const LoginOutcome({required this.registered, required this.signedIn});
}

class LoginEngine {
  final UserOperationsService ops;

  /// Infer HQ mode from compile-time define; you can also pass it manually.
  final bool isHq;

  /// Allow INVITED users during explicit invite-accept flow.
  /// For normal login keep false (ACTIVE only).
  final bool allowInvitedForInviteFlow;

  LoginEngine({
    required this.ops,
    bool? isHq,
    this.allowInvitedForInviteFlow = false,
  }) : isHq =
           isHq ??
           (const String.fromEnvironment('APP_MODE', defaultValue: 'tenant') ==
               'hq');

  Future<Result<LoginOutcome>> login(
    String rawEmail,
    String rawPassword,
  ) async {
    try {
      final email = EmailHelper.normalize(rawEmail);
      final password = rawPassword.trim();
      if (email.isEmpty || password.isEmpty) {
        return Err(AppError('auth/invalid-input', 'Email & password required'));
      }

      // 1) STRICT precheck for tenants (blocks wrong/inactive before hitting Firebase)
      if (!isHq) {
        final ok = await ops.isTenantMemberEmail(
          email,
          allowInvitedForInviteFlow: allowInvitedForInviteFlow,
        );
        if (!ok) {
          return Err(
            AppError(
              'auth/not-tenant-member',
              allowInvitedForInviteFlow
                  ? "This account isn't invited/active on this tenant."
                  : "This account isn't active on this tenant.",
            ),
          );
        }
      } else {
        debugPrint('🔐 [LoginEngine] HQ mode → skip pre-check');
      }

      // 2) Firebase Auth sign-in
      await ops.signInWithEmailAndPassword(email: email, password: password);
      await ops.waitForUserSignIn();
      await ops.getIdToken(forceRefresh: true); // ensure fresh token

      // 3) Post sign-in enforcement
      if (isHq) {
        final claims = await ops.getClaims(retries: 5);
        final allowed =
            (claims['hq'] == true) || (claims['superadmin'] == true);
        if (!allowed) {
          await ops.signOut();
          return Err(
            AppError(
              'auth/no-hq-access',
              'HQ access required for this account.',
            ),
          );
        }
      } else {
        final expected = ops.expectedTenantId; // set by createWithBackend
        if (expected != null && expected.isNotEmpty) {
          try {
            // Throws if membership missing or not ACTIVE (after backend hardening)
            await ops.ensureTenantClaimSelected(
              expected,
              reason: 'LoginEngine.login',
            );
          } catch (e) {
            await ops.signOut();
            final mapped = _mapSyncClaimsError(e);
            return Err(
              mapped ??
                  AppError(
                    'auth/wrong-tenant',
                    'This account does not belong to this tenant.',
                  ),
            );
          }
        }
      }

      return Ok(const LoginOutcome(registered: true, signedIn: true));
    } catch (e) {
      return Err(AppError('auth/login-failed', 'Login failed', cause: e));
    }
  }

  Future<Result<void>> sendPasswordReset(String rawEmail) async {
    try {
      final email = EmailHelper.normalize(rawEmail);
      if (!EmailHelper.isValid(email)) {
        return Err(AppError('auth/bad-email', 'Invalid email'));
      }

      // Tenant: pre-check existence to avoid leaking info; HQ skips.
      if (!isHq) {
        final isKnown = await ops.isEmailRegistered(email);
        if (!isKnown) {
          return Err(AppError('auth/not-registered', 'Email not registered'));
        }
      } else {
        debugPrint('🔧 [LoginEngine] HQ mode → skip reset pre-check');
      }

      await ops.sendPasswordResetEmail(email, viaBackend: true);
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError('auth/reset-failed', 'Password reset failed', cause: e),
      );
    }
  }

  Future<Result<void>> signOut() async {
    try {
      await ops.signOut();
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/signout-failed', 'Sign out failed', cause: e));
    }
  }

  Future<bool> isSignedIn() async => await ops.isLoggedIn();

  Future<Result<void>> refreshIdToken() async {
    try {
      await ops.getIdToken(forceRefresh: true);
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
