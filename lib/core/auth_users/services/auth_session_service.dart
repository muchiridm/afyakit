// lib/core/auth_users/services/auth_session_service.dart
import 'dart:async';

import 'package:afyakit/api/afyakit/client.dart';
import 'package:afyakit/api/afyakit/routes.dart';
import 'package:afyakit/api/afyakit/config.dart'; // ⬅️ NEW
import 'package:afyakit/core/auth_users/providers/auth_session/token_provider.dart';
import 'package:afyakit/core/auth_users/utils/auth_claims.dart';
import 'package:afyakit/shared/utils/dev_trace.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authSessionServiceProvider =
    FutureProvider.family<AuthSessionService, String>((ref, tenantId) async {
      final tokens = ref.read(tokenProvider);
      return AuthSessionService.create(
        tenantId: tenantId,
        tokens: tokens,
        withAuth: true,
      );
    });

class AuthSessionService {
  AuthSessionService._(
    this._auth,
    this._client,
    this._routes, {
    required this.tenantId,
  });

  // Deps
  final fb.FirebaseAuth _auth;
  final AfyaKitClient _client;
  final AfyaKitRoutes _routes;
  final String tenantId;

  static const _delayedRefreshDelay = Duration(seconds: 2);

  // ─────────────────────────────────────────────────────────
  // UPDATED FACTORY (aligned with new AfyaKitClient API)
  // ─────────────────────────────────────────────────────────
  static Future<AuthSessionService> create({
    required String tenantId,
    required TokenProvider tokens,
    bool withAuth = true,
  }) async {
    final span = DevTrace(
      'authSessionService.create',
      context: {'tenant': tenantId, 'withAuth': withAuth},
    );

    final base = apiBaseUrl(tenantId);

    final client = await AfyaKitClient.create(
      baseUrl: base,
      // when withAuth=false, we never attach a token (and refresh path no-ops)
      getToken: () async => withAuth ? await tokens.tryGetToken() : null,
    );

    span.log('baseUrl', add: {'url': base, 'withAuth': withAuth});
    span.done('client ready');

    return AuthSessionService._(
      fb.FirebaseAuth.instance,
      client,
      AfyaKitRoutes(tenantId),
      tenantId: tenantId,
    );
  }

  Dio get _dio => _client.dio;

  // ── helpers ─────────────────────────────────────────────────
  String? _tenantFromClaims(Map<String, dynamic> claims) {
    final t = claims['tenantId'] ?? claims['tenant'];
    return t?.toString();
  }

  void _logClaimsBrief(Map<String, dynamic> claims, {String? prefix}) {
    final keys = (claims.keys.toList()..sort()).join(',');
    final tenant = _tenantFromClaims(claims);
    final role = claims['role'];
    final superadmin = claims['superadmin'] ?? claims['superAdmin'];
    debugPrint(
      '${prefix ?? '🔍 Claims'} tenantId=$tenant role=$role superadmin=$superadmin keys=$keys',
    );
  }

  // ── firebase session helpers ────────────────────────────────
  Future<void> waitForUser() async {
    try {
      await _auth.authStateChanges().first.timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
      final u = _auth.currentUser;
      debugPrint(
        u != null
            ? '✅ Firebase user restored: ${u.email}'
            : '👻 No Firebase user',
      );
    } catch (_) {
      debugPrint('⏳ FirebaseAuth hydration timed out.');
    }
  }

  Future<void> waitForUserSignIn() => waitForUser();

  fb.User? getCurrentUser() => _auth.currentUser;

  Future<void> signOut() async {
    final email = _auth.currentUser?.email;
    await _auth.signOut();
    debugPrint('🔒 User signed out: $email');
  }

  Future<bool> isLoggedIn() async => _auth.currentUser != null;

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final u = _auth.currentUser;
    return u?.getIdToken(forceRefresh);
  }

  Future<void> forceRefreshIdToken() async {
    await _auth.currentUser?.getIdToken(true);
  }

  // ── claims (DRY via ClaimsUtils) ────────────────────────────
  Future<Map<String, dynamic>> getClaims({bool force = true}) async {
    final hasUser = _auth.currentUser != null;
    final actuallyForce = force && hasUser;

    try {
      final claims = await ClaimsUtils.read(force: actuallyForce);
      if (claims.isEmpty) {
        debugPrint('⚠️ getClaims(force=$actuallyForce) → empty');
      }
      return claims;
    } on fb.FirebaseAuthException catch (e) {
      debugPrint('⚠️ getClaims auth error (${e.code})');
      return const {};
    } catch (_) {
      return const {};
    }
  }

  /// Ask server to sync claims. Returns a **non-forced** snapshot of claims.
  /// Schedules a delayed forced ID-token refresh (non-blocking).
  Future<Map<String, dynamic>> syncClaimsAndRefresh() async {
    final t = DevTrace('sync-claims', context: {'tenant': tenantId});
    final uri = _routes.syncClaims();

    if (_auth.currentUser == null) {
      t.done('no-fbUser → skip');
      return const <String, dynamic>{};
    }

    try {
      t.log('POST', add: {'uri': uri.toString()});
      await _dio.postUri(uri);
    } on DioException catch (e) {
      final sc = e.response?.statusCode ?? 0;
      if (sc != 403 && sc != 404) {
        t.done('server-error $sc');
        rethrow;
      }
      t.log('ignore', add: {'status': sc});
    } catch (e) {
      t.log('server-call-swallowed', add: {'err': e.toString()});
    }

    Map<String, dynamic> claims = const {};
    try {
      claims = await getClaims(force: false);
      _logClaimsBrief(claims, prefix: '✅ Claims sync requested (no force)');
    } catch (e) {
      t.log('claims-read-soft-fail', add: {'err': e.toString()});
    }

    Future<void>.delayed(_delayedRefreshDelay, () async {
      try {
        final u = _auth.currentUser;
        if (u == null) {
          t.log('delayed-refresh-ignored', add: {'reason': 'no-current-user'});
          return;
        }
        final fresh = await u.getIdToken(true);
        t.log('delayed-refresh-ok', add: {'len': fresh?.length ?? 0});
      } on fb.FirebaseAuthException catch (e) {
        t.log('delayed-refresh-autherr', add: {'code': e.code});
      } catch (e) {
        t.log('delayed-refresh-error', add: {'err': e.toString()});
      }
    });

    t.done('ok (no-force)');
    return claims;
  }

  /// Softly ensure the tenant claim matches the selected tenant.
  Future<Map<String, dynamic>> ensureTenantClaimSelected(
    String expectedTenantId, {
    String? reason,
  }) async {
    final before = await getClaims(force: false);
    final beforeTenant = _tenantFromClaims(before);
    debugPrint(
      '🧭 ensureTenantClaimSelected($expectedTenantId)'
      '${reason != null ? ' reason=$reason' : ''} → current=$beforeTenant',
    );
    if (beforeTenant == expectedTenantId) {
      _logClaimsBrief(before, prefix: '✅ Tenant claim already correct');
      return before;
    }

    unawaited(() async {
      try {
        await syncClaimsAndRefresh();
        await Future<void>.delayed(const Duration(seconds: 2));
        await getClaims(force: false);
      } catch (_) {}
    }());

    _logClaimsBrief(
      before,
      prefix:
          '⚠️ Tenant claim mismatch (claim=$beforeTenant, selected=$expectedTenantId) — continuing soft',
    );
    return before;
  }
}
