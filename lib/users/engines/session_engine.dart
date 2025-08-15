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

      final email = u.email?.trim().toLowerCase();
      if (email == null || email.isEmpty) {
        return Err(AppError('auth/no-email', 'Firebase user has no email'));
      }

      // 🔑 Always let the helper decide whether to sync/hydrate
      await _syncClaimsIfNeeded(email: email, uid: u.uid);

      // Canonical fetch (also keeps backend/session in sync)
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

      // Same logic on reload: hydrate if claims are incomplete
      await _syncClaimsIfNeeded(email: email, uid: u.uid);

      final authUser = await session.checkUserStatus(email: email);
      return Ok(authUser);
    } catch (e) {
      return Err(
        AppError('session/reload-failed', 'Failed to reload session', cause: e),
      );
    }
  }

  /// If claims are missing tenant → trigger server sync.
  /// If claims are valid but missing profile bits (role/stores) → hydrate from model by
  /// calling `checkUserStatus(email)`, which returns the authoritative AuthUser.
  Future<void> _syncClaimsIfNeeded({required String email, String? uid}) async {
    await auth.refreshToken();
    final claims = await auth.getClaims();

    // 1) No tenant claim → force backend to stamp claims/session.
    if (!ClaimValidator.isValid(claims)) {
      if (email.isNotEmpty) {
        await session.checkUserStatus(email: email);
      }
      return;
    }

    // 2) Tenant present but profile bits may be stale/missing in claims.
    //    Hydrate the in-memory user from the canonical model.
    if (ClaimValidator.shouldHydrateFromModel(claims)) {
      if (email.isNotEmpty) {
        await session.checkUserStatus(email: email);
      }
    }
    // Otherwise: claims good enough; nothing to do.
  }
}
