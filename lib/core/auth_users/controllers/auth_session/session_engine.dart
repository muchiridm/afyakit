import 'package:afyakit/core/auth_users/extensions/user_status_x.dart';
import 'package:afyakit/core/auth_users/services/auth_session_service.dart';
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/types/app_error.dart';
import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/utils/claim_validator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionEngineProvider = FutureProvider.family
    .autoDispose<SessionEngine, String>((ref, tenantId) async {
      final ops = await ref.read(authSessionServiceProvider(tenantId).future);
      return SessionEngine(ops: ops, tenantId: tenantId);
    });

class SessionEngine {
  final AuthSessionService ops;
  final String tenantId;

  // Treat HQ as a distinct mode (no tenant claim work / no tenant session calls)
  final bool _hqMode;

  SessionEngine({required this.ops, required this.tenantId, bool? hqMode})
    : _hqMode = hqMode ?? (tenantId == 'hq');

  Future<Result<AuthUser?>> ensureReady() async {
    try {
      await ops.waitForUser();

      if (_hqMode) {
        _log('[HQ] ensureReady → skip tenant status & claims');
        return const Ok<AuthUser?>(null);
      }

      final u = ops.getCurrentUser();
      if (u == null) return const Ok<AuthUser?>(null);

      final email = (u.email ?? '').trim().toLowerCase();
      if (email.isEmpty) {
        return Err(AppError('auth/no-email', 'Firebase user has no email'));
      }

      await _ensureTenantSelected(email: email, reason: 'ensureReady');
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
      final u = ops.getCurrentUser();
      if (u == null) return const Ok<AuthUser?>(null);

      final email = (u.email ?? '').trim().toLowerCase();
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

  Future<Result<AuthUser?>> refreshTokenAndClaimsAndUser() async {
    try {
      if (_hqMode) {
        await ops
            .forceRefreshIdToken(); // still pick up any server-side changes
        return const Ok<AuthUser?>(null);
      }

      final fbUser = ops.getCurrentUser();
      if (fbUser == null) return const Ok<AuthUser?>(null);

      final email = (fbUser.email ?? '').trim().toLowerCase();
      if (email.isEmpty) {
        return Err(AppError('auth/no-email', 'Firebase user has no email'));
      }

      await ops.forceRefreshIdToken();
      await _ensureTenantSelected(email: email, reason: 'soft-refresh');
      final authUser = await ops.checkUserStatus(email: email);
      return Ok(authUser);
    } catch (e, st) {
      _log('❌ SessionEngine.refreshTokenAndClaimsAndUser error: $e\n$st');
      return Err(
        AppError(
          'session/soft-refresh-failed',
          'Failed to softly refresh session',
          cause: e,
        ),
      );
    }
  }

  Future<void> _ensureTenantSelected({
    required String email,
    required String reason,
  }) async {
    // Peek current claims without forcing a refresh
    var claims = await ops.getClaims(force: false);
    final claimTenant = _tenantFromClaims(claims);

    if (kDebugMode) {
      _log(
        '🧭 _ensureTenantSelected($reason) claimTenant=$claimTenant target=$tenantId',
      );
    }

    // Already on the right tenant? Nothing to do.
    if (claimTenant == tenantId) {
      // Optional light validation; do not fail hard for invited users.
      if (!ClaimValidator.isValid(claims)) {
        try {
          await ops.checkUserStatus(email: email);
          await ops.forceRefreshIdToken();
          claims = await ops.getClaims(force: true);
        } catch (e) {
          _log('⚠️ Claim validate/hydrate (already-correct tenant) failed: $e');
        }
      }
      return;
    }

    // Not on the right tenant → check membership
    AuthUser authUser;
    try {
      authUser = await ops.checkUserStatus(email: email);
    } catch (e) {
      _log('⚠️ Membership probe failed (tenant=$tenantId, email=$email): $e');
      rethrow; // real membership errors should surface
    }

    final isActive = authUser.status.isActive;
    if (!isActive) {
      _log(
        'ℹ️ User is ${authUser.status.name} on $tenantId → skipping claims sync; continuing limited mode.',
      );
      return;
    }

    // Active member → perform claim sync and verify
    try {
      await ops.ensureTenantClaimSelected(
        tenantId,
        reason: 'SessionEngine.$reason',
      );
      await ops.forceRefreshIdToken(); // pick up fresh claims
      claims = await ops.getClaims(force: true); // verify
    } catch (e) {
      _log('⚠️ Tenant claim sync failed ($claimTenant → $tenantId): $e');

      // Only hard boot on definitive membership errors — NOT on transient 'auth/forbidden'
      if (e is AppError &&
          (e.code == 'auth/membership-not-found' ||
              e.code == 'auth/user-not-active')) {
        try {
          await ops.signOut();
        } catch (_) {}
      }

      rethrow;
    }

    if (!ClaimValidator.isValid(claims)) {
      try {
        await ops.checkUserStatus(email: email);
        await ops.forceRefreshIdToken();
        claims = await ops.getClaims(force: true);
      } catch (e) {
        _log('⚠️ Claim validate/hydrate (post-sync) failed: $e');
      }
    }

    if (ClaimValidator.shouldHydrateFromModel(claims)) {
      try {
        await ops.checkUserStatus(email: email);
      } catch (_) {}
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
