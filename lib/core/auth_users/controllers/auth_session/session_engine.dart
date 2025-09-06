// lib/core/auth_users/controllers/auth_session/session_engine.dart
import 'package:afyakit/core/auth_users/extensions/user_status_x.dart';
import 'package:afyakit/core/auth_users/services/auth_session_service.dart';
import 'package:afyakit/core/auth_users/services/login_service.dart';
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/types/app_error.dart';
import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/utils/claim_validator.dart';
import 'package:dio/dio.dart' show DioException; // ⬅️ add
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionEngineProvider = FutureProvider.family
    .autoDispose<SessionEngine, String>((ref, tenantId) async {
      final sessionOps = await ref.read(
        authSessionServiceProvider(tenantId).future,
      );
      final loginOps = await ref.read(loginServiceProvider(tenantId).future);
      return SessionEngine(
        session: sessionOps,
        loginSvc: loginOps,
        tenantId: tenantId,
      );
    });

class SessionEngine {
  final AuthSessionService session;
  final LoginService loginSvc;
  final String tenantId;
  final bool _hqMode;

  SessionEngine({
    required this.session,
    required this.loginSvc,
    required this.tenantId,
    bool? hqMode,
  }) : _hqMode = hqMode ?? (tenantId == 'hq');

  Future<Result<AuthUser?>> ensureReady() async {
    try {
      await session.waitForUser();

      if (_hqMode) {
        _log('[HQ] ensureReady → skip tenant status & claims');
        return const Ok<AuthUser?>(null);
      }

      final u = session.getCurrentUser();
      if (u == null) return const Ok<AuthUser?>(null);

      final email = (u.email ?? '').trim().toLowerCase();
      if (email.isEmpty) {
        return Err(AppError('auth/no-email', 'Firebase user has no email'));
      }

      await _ensureTenantSelected(email: email, reason: 'ensureReady');
      final authUser = await _probeMembership(email);
      return Ok(authUser);
    } on AppError catch (ae) {
      _log('❌ ensureReady app-error: ${ae.code} ${ae.message}');
      return Err(ae);
    } catch (e, st) {
      _log('❌ SessionEngine.ensureReady error: $e\n$st');
      return Err(
        AppError('session/init-failed', 'Failed to init session', cause: e),
      );
    }
  }

  Future<Result<AuthUser?>> reload() async {
    try {
      final u = session.getCurrentUser();
      if (u == null) return const Ok<AuthUser?>(null);

      final email = (u.email ?? '').trim().toLowerCase();
      await _ensureTenantSelected(email: email, reason: 'reload');

      final authUser = await _probeMembership(email);
      return Ok(authUser);
    } on AppError catch (ae) {
      return Err(ae);
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
        await session.forceRefreshIdToken();
        return const Ok<AuthUser?>(null);
      }

      final fbUser = session.getCurrentUser();
      if (fbUser == null) return const Ok<AuthUser?>(null);

      final email = (fbUser.email ?? '').trim().toLowerCase();
      if (email.isEmpty) {
        return Err(AppError('auth/no-email', 'Firebase user has no email'));
      }

      await session.forceRefreshIdToken();
      await _ensureTenantSelected(email: email, reason: 'soft-refresh');
      final authUser = await _probeMembership(email);
      return Ok(authUser);
    } on AppError catch (ae) {
      return Err(ae);
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

  // ── internal ─────────────────────────────────────────────────

  /// Normalize backend responses: 404/403 → AppError
  Future<AuthUser> _probeMembership(String email) async {
    try {
      return await loginSvc.checkUserStatus(email: email);
    } on DioException catch (e) {
      final sc = e.response?.statusCode ?? 0;
      final code =
          (e.response?.data is Map && (e.response!.data)['error'] is String)
          ? e.response!.data['error'] as String
          : null;

      if (sc == 404) {
        throw AppError(
          'auth/membership-not-found',
          'No access to this tenant.',
          cause: e,
        );
      }
      if (sc == 403 && code == 'USER_NOT_ACTIVE') {
        throw AppError(
          'auth/user-not-active',
          'Your access to this tenant is not active.',
          cause: e,
        );
      }
      rethrow;
    }
  }

  Future<void> _ensureTenantSelected({
    required String email,
    required String reason,
  }) async {
    var claims = await session.getClaims(force: false);
    final claimTenant = _tenantFromClaims(claims);

    if (kDebugMode) {
      _log(
        '🧭 _ensureTenantSelected($reason) claimTenant=$claimTenant target=$tenantId',
      );
    }

    if (claimTenant == tenantId) {
      if (!ClaimValidator.isValid(claims)) {
        try {
          await _probeMembership(email);
          await session.forceRefreshIdToken();
          claims = await session.getClaims(force: true);
        } catch (e) {
          _log('⚠️ Claim validate/hydrate (already-correct tenant) failed: $e');
        }
      }
      return;
    }

    // Not on right tenant → membership gate
    late final AuthUser authUser;
    try {
      authUser = await _probeMembership(email);
    } on AppError catch (ae) {
      // Wrong tenant: sign out to avoid carrying stale claims
      if (ae.code == 'auth/membership-not-found' ||
          ae.code == 'auth/user-not-active') {
        try {
          await loginSvc.signOut();
        } catch (_) {}
      }
      throw ae;
    }

    if (!authUser.status.isActive) {
      _log(
        'ℹ️ User is ${authUser.status.name} on $tenantId → limited mode; skip claim sync.',
      );
      return;
    }

    try {
      await session.ensureTenantClaimSelected(
        tenantId,
        reason: 'SessionEngine.$reason',
      );
      await session.forceRefreshIdToken();
      claims = await session.getClaims(force: true);
    } catch (e) {
      _log('⚠️ Tenant claim sync failed ($claimTenant → $tenantId): $e');
      rethrow;
    }

    if (!ClaimValidator.isValid(claims)) {
      try {
        await _probeMembership(email);
        await session.forceRefreshIdToken();
        await session.getClaims(force: true);
      } catch (e) {
        _log('⚠️ Claim validate/hydrate (post-sync) failed: $e');
      }
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
