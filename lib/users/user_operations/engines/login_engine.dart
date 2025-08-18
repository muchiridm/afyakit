import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/types/app_error.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:afyakit/users/user_operations/services/user_operations_service.dart';

class LoginOutcome {
  final bool registered;
  final bool signedIn;
  const LoginOutcome({required this.registered, required this.signedIn});
}

class LoginEngine {
  final UserOperationsService ops;
  LoginEngine({required this.ops});

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

      final isKnown = await ops.isEmailRegistered(email);
      if (!isKnown) {
        return Ok(const LoginOutcome(registered: false, signedIn: false));
      }

      await ops.signInWithEmailAndPassword(email: email, password: password);
      await ops.waitForUserSignIn();
      await ops.getIdToken(forceRefresh: true);

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
      final isKnown = await ops.isEmailRegistered(email);
      if (!isKnown) {
        return Err(AppError('auth/not-registered', 'Email not registered'));
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

  /// Controller-friendly helpers (no Firebase types in UI)
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
