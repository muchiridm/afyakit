// lib/users/engines/session_engine.dart
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/types/app_error.dart';
import 'package:afyakit/users/services/firebase_auth_service.dart';
import 'package:afyakit/users/services/user_session_service.dart';
import 'package:afyakit/users/models/auth_user_model.dart';
import 'package:afyakit/users/utils/claim_validator.dart';

class SessionEngine {
  final FirebaseAuthService auth;
  final UserSessionService session;

  SessionEngine({required this.auth, required this.session});

  Future<Result<AuthUser?>> ensureReady() async {
    try {
      await auth.waitForUser();
      final u = await auth.getCurrentUser();
      if (u == null) return const Ok(null); // not signed in

      await _syncClaimsIfNeeded();
      final email = u.email?.trim().toLowerCase();
      if (email == null || email.isEmpty) {
        return Err(AppError('auth/no-email', 'Firebase user has no email'));
      }
      final authUser = await session.checkUserStatus(email: email);
      return Ok(authUser);
    } catch (e) {
      return Err(
        AppError('session/init-failed', 'Failed to init session', cause: e),
      );
    }
  }

  Future<Result<AuthUser?>> reload() async {
    try {
      final u = await auth.getCurrentUser();
      if (u == null) return const Ok(null);
      await auth.refreshToken();
      final email = u.email?.trim().toLowerCase() ?? '';
      final authUser = await session.checkUserStatus(email: email);
      return Ok(authUser);
    } catch (e) {
      return Err(
        AppError('session/reload-failed', 'Failed to reload session', cause: e),
      );
    }
  }

  Future<void> _syncClaimsIfNeeded() async {
    await auth.refreshToken();
    final claims = await auth.getClaims();
    if (ClaimValidator.isValid(claims)) return;
    // trigger backend sync by pinging status endpoint
    final u = await auth.getCurrentUser();
    if (u?.email != null) {
      await session.checkUserStatus(email: u!.email!);
    }
  }
}
