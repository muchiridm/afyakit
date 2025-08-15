// lib/users/engines/login_engine.dart
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/types/app_error.dart';
import 'package:afyakit/users/services/firebase_auth_service.dart';
import 'package:afyakit/users/services/user_session_service.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';

class LoginOutcome {
  final bool registered;
  final bool signedIn;
  const LoginOutcome({required this.registered, required this.signedIn});
}

class LoginEngine {
  final FirebaseAuthService auth;
  final UserSessionService session;

  LoginEngine({required this.auth, required this.session});

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

      final allowed = await session.isEmailRegistered(email);
      if (!allowed) {
        return Ok(const LoginOutcome(registered: false, signedIn: false));
      }

      await auth.signInWithEmailAndPassword(email: email, password: password);
      await auth.waitForUserSignIn();
      await auth.getIdToken(forceRefresh: true);
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
      final allowed = await session.isEmailRegistered(email);
      if (!allowed) {
        return Err(AppError('auth/not-registered', 'Email not registered'));
      }
      await session.sendPasswordResetEmail(email);
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError('auth/reset-failed', 'Password reset failed', cause: e),
      );
    }
  }
}
