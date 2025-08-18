// lib/users/engines/session_engine.dart
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/types/app_error.dart';
import 'package:afyakit/users/user_operations/services/user_operations_service.dart';
import 'package:afyakit/users/user_manager/models/auth_user_model.dart';
import 'package:afyakit/users/utils/claim_validator.dart';

class SessionEngine {
  final UserOperationsService ops;
  SessionEngine({required this.ops});

  Future<Result<AuthUser?>> ensureReady() async {
    try {
      await ops.waitForUser();

      final u = await ops.getCurrentUser();
      if (u == null) return const Ok<AuthUser?>(null); // not signed in

      final email = (u.email ?? '').trim().toLowerCase();
      if (email.isEmpty) {
        return Err(AppError('auth/no-email', 'Firebase user has no email'));
      }

      await _syncClaimsIfNeeded(email: email, uid: u.uid);

      // Canonical load (authoritative source via backend)
      final authUser = await ops.checkUserStatus(email: email);
      return Ok(authUser);
    } catch (e) {
      return Err(
        AppError('session/init-failed', 'Failed to init session', cause: e),
      );
    }
  }

  Future<Result<AuthUser?>> reload() async {
    try {
      final u = await ops.getCurrentUser();
      if (u == null) return const Ok<AuthUser?>(null);

      await ops.refreshToken();
      final email = (u.email ?? '').trim().toLowerCase();

      await _syncClaimsIfNeeded(email: email, uid: u.uid);

      final authUser = await ops.checkUserStatus(email: email);
      return Ok(authUser);
    } catch (e) {
      return Err(
        AppError('session/reload-failed', 'Failed to reload session', cause: e),
      );
    }
  }

  /// If claims are missing tenant → trigger server sync (via checkUserStatus).
  /// If claims are valid but profile bits are stale → hydrate from model.
  Future<void> _syncClaimsIfNeeded({required String email, String? uid}) async {
    await ops.refreshToken();
    final claims = await ops.getClaims();

    if (!ClaimValidator.isValid(claims)) {
      if (email.isNotEmpty) {
        await ops.checkUserStatus(email: email);
      }
      return;
    }

    if (ClaimValidator.shouldHydrateFromModel(claims)) {
      if (email.isNotEmpty) {
        await ops.checkUserStatus(email: email);
      }
    }
  }
}
