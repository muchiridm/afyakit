// lib/users/engines/session_engine.dart
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/types/app_error.dart';
import 'package:afyakit/core/auth_users/services/user_operations_service.dart';
import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/utils/claim_validator.dart';
import 'package:flutter/foundation.dart';

class SessionEngine {
  final UserOperationsService ops;
  final String tenantId;

  // Treat HQ as a distinct mode (no tenant claim work / no tenant session calls)
  final bool _hqMode;

  SessionEngine({required this.ops, required this.tenantId, bool? hqMode})
    : _hqMode = hqMode ?? (tenantId == 'hq');

  Future<Result<AuthUser?>> ensureReady() async {
    try {
      await ops.waitForUser();

      // ⛔ HQ: do not ping tenant endpoints; HqGate handles superadmin gating.
      if (_hqMode) {
        _log('[HQ] ensureReady → skip tenant status & claims');
        return const Ok<AuthUser?>(null);
      }

      final u = await ops.getCurrentUser();
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
      // ⛔ HQ: nothing to reload from tenant. Keep it a no-op.
      if (_hqMode) {
        _log('[HQ] reload → skip tenant status & claims');
        return const Ok<AuthUser?>(null);
      }

      final u = await ops.getCurrentUser();
      if (u == null) return const Ok<AuthUser?>(null);

      await ops.refreshToken();
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

  Future<void> _ensureTenantSelected({
    required String email,
    required String reason,
  }) async {
    if (_hqMode) {
      _log('[HQ] _ensureTenantSelected($reason) → no-op');
      return;
    }

    await ops.refreshToken();
    var claims = await ops.getClaims();

    final claimTenant = _tenantFromClaims(claims);
    if (kDebugMode) {
      _log(
        '🧭 _ensureTenantSelected($reason) claimTenant=$claimTenant target=$tenantId',
      );
    }

    if (claimTenant != tenantId) {
      try {
        await ops.checkUserStatus(email: email);
        await ops.ensureTenantClaimSelected(
          tenantId,
          reason: 'SessionEngine.$reason',
        );
        claims = await ops.getClaims();
      } catch (e) {
        _log('⚠️ Tenant claim sync failed ($claimTenant → $tenantId): $e');
        try {
          await ops.checkUserStatus(email: email);
        } catch (_) {}
      }
    }

    if (!ClaimValidator.isValid(claims)) {
      try {
        await ops.checkUserStatus(email: email);
        claims = await ops.getClaims();
      } catch (e) {
        _log('⚠️ Claim validate/hydrate failed: $e');
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
