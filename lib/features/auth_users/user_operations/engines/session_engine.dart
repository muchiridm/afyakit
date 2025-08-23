// lib/users/engines/session_engine.dart
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/types/app_error.dart';
import 'package:afyakit/features/auth_users/user_operations/services/user_operations_service.dart';
import 'package:afyakit/features/auth_users/models/auth_user_model.dart';
import 'package:afyakit/features/auth_users/utils/claim_validator.dart';
import 'package:flutter/foundation.dart';

class SessionEngine {
  final UserOperationsService ops;
  final String tenantId; // ✅ needed to align custom claim with selected tenant

  SessionEngine({required this.ops, required this.tenantId});

  Future<Result<AuthUser?>> ensureReady() async {
    try {
      await ops.waitForUser();

      final u = await ops.getCurrentUser();
      if (u == null) return const Ok<AuthUser?>(null); // not signed in

      final email = (u.email ?? '').trim().toLowerCase();
      if (email.isEmpty) {
        return Err(AppError('auth/no-email', 'Firebase user has no email'));
      }

      // 🔑 Make sure the token's tenantId matches the selected tenant
      await _ensureTenantSelected(email: email, reason: 'ensureReady');

      // Canonical load (authoritative source via backend)
      final authUser = await ops.checkUserStatus(email: email);
      return Ok(authUser);
    } catch (e, st) {
      _log('❌ SessionEngine.ensureReady error: $e\n$st');
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

      // 🔑 Keep tenant claim aligned on reload too
      await _ensureTenantSelected(email: email, reason: 'reload');

      final authUser = await ops.checkUserStatus(email: email);
      return Ok(authUser);
    } catch (e, st) {
      _log('❌ SessionEngine.reload error: $e\n$st');
      return Err(
        AppError('session/reload-failed', 'Failed to reload session', cause: e),
      );
    }
  }

  /// Ensures claims are valid and that the active tenant claim equals [tenantId].
  /// If claims are missing, we nudge the server via checkUserStatus and sync.
  /// If profile bits look stale, we hydrate from model (via checkUserStatus).
  Future<void> _ensureTenantSelected({
    required String email,
    required String reason,
  }) async {
    // Always start from a fresh token snapshot
    await ops.refreshToken();
    var claims = await ops.getClaims();

    final claimTenant = _tenantFromClaims(claims);
    if (kDebugMode) {
      _log(
        '🧭 _ensureTenantSelected($reason) claimTenant=$claimTenant target=$tenantId',
      );
    }

    // If the active tenant in the token doesn't match, fix it first.
    if (claimTenant != tenantId) {
      // Seed/confirm server session for this tenant (optional but harmless)
      await ops.checkUserStatus(email: email);

      // Ask backend to set correct tenant claim, then refresh token
      await ops.ensureTenantClaimSelected(
        tenantId,
        reason: 'SessionEngine.$reason',
      );

      // Re-read claims after correction
      claims = await ops.getClaims();
    }

    // Now claims should be present; if not, nudge server again
    if (!ClaimValidator.isValid(claims)) {
      await ops.checkUserStatus(email: email);
      claims = await ops.getClaims();
    }

    // If mirrored fields look stale, hydrate from model
    if (ClaimValidator.shouldHydrateFromModel(claims)) {
      await ops.checkUserStatus(email: email);
    }
  }

  String? _tenantFromClaims(Map<String, dynamic> claims) {
    final v = claims['tenantId'] ?? claims['tenant'];
    return v?.toString();
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint(msg);
  }
}
