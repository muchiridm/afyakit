import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/types/app_error.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:afyakit/core/auth_users/services/user_operations_service.dart';
import 'package:flutter/foundation.dart';

class LoginOutcome {
  final bool registered;
  final bool signedIn;
  const LoginOutcome({required this.registered, required this.signedIn});
}

class LoginEngine {
  final UserOperationsService ops;

  /// Infer HQ mode from compile-time define; you can also pass it in manually.
  final bool isHq;
  LoginEngine({required this.ops, bool? isHq})
    : isHq =
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

      if (!isHq) {
        // Tenant flow → keep pre-check for fast UX.
        final isKnown = await ops.isEmailRegistered(email);
        if (!isKnown) {
          // ⚠️ This is what was triggering your red banner before.
          return Ok(const LoginOutcome(registered: false, signedIn: false));
        }
      } else {
        debugPrint('🔐 [LoginEngine] HQ mode → skip pre-check');
      }

      // Sign in (HQ always reaches here because we skipped the pre-check).
      await ops.signInWithEmailAndPassword(email: email, password: password);
      await ops.waitForUserSignIn();
      await ops.getIdToken(forceRefresh: true); // ensure fresh claims

      if (isHq) {
        final claims = await ops.getClaims(retries: 5);
        debugPrint('🔐 [LoginEngine] HQ claims → $claims');

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

      // Tenant keeps pre-check; HQ allows reset regardless.
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
}
