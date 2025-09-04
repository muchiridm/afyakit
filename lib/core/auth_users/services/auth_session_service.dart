// lib/core/auth_users/services/auth_session_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:afyakit/api/api_client.dart';
import 'package:afyakit/api/api_routes.dart';
import 'package:afyakit/core/auth_users/extensions/user_status_x.dart';
import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/providers/auth_session/token_provider.dart';
import 'package:afyakit/core/auth_users/utils/auth_claims.dart';
import 'package:afyakit/shared/utils/dev_trace.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
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

class _Timed<T> {
  final T value;
  final DateTime at;
  static const _ttl = Duration(seconds: 8);
  _Timed(this.value) : at = DateTime.now();
  bool get fresh => DateTime.now().difference(at) < _ttl;
}

class AuthSessionService {
  AuthSessionService._(
    this._auth,
    this._client,
    this._routes,
    this._tokens, {
    required this.tenantId,
  });

  // Deps
  final fb.FirebaseAuth _auth;
  final ApiClient _client;
  final ApiRoutes _routes;
  final TokenProvider _tokens;
  final String tenantId;

  static const _delayedRefreshDelay = Duration(seconds: 2);

  static Future<AuthSessionService> create({
    required String tenantId,
    required TokenProvider tokens,
    bool withAuth = true,
  }) async {
    final t = DevTrace('apiClient.create', context: {'tenant': tenantId});
    final client = await ApiClient.create(
      tenantId: tenantId,
      tokenProvider: tokens,
      withAuth: withAuth,
    );
    t.log('baseUrl', add: {'url': client.baseUrl, 'withAuth': withAuth});
    t.done('auth http client ready');
    return AuthSessionService._(
      fb.FirebaseAuth.instance,
      client,
      ApiRoutes(tenantId),
      tokens,
      tenantId: tenantId,
    );
  }

  Dio get _dio => _client.dio;

  // ── helpers ─────────────────────────────────────────────────
  String _clean(String? s) => (s ?? '').trim();
  String _normalizeEmail(String s) => EmailHelper.normalize(s);

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

  // ── tiny status cache ───────────────────────────────────────
  final Map<String, _Timed<AuthUser>> _statusCache = {};
  String _statusKey({String? email, String? phoneNumber}) =>
      '${(email ?? '').trim().toLowerCase()}|${(phoneNumber ?? '').trim()}';

  AuthUser? _getCachedStatus({String? email, String? phoneNumber}) {
    final k = _statusKey(email: email, phoneNumber: phoneNumber);
    final hit = _statusCache[k];
    return (hit != null && hit.fresh) ? hit.value : null;
  }

  void _cacheStatus(AuthUser u, {String? email, String? phoneNumber}) {
    final k = _statusKey(email: email, phoneNumber: phoneNumber);
    _statusCache[k] = _Timed(u);
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
    // If there is no user, a forced read is meaningless on web; fall back to soft.
    final hasUser = _auth.currentUser != null;
    final actuallyForce = force && hasUser;

    try {
      final claims = await ClaimsUtils.read(force: actuallyForce);
      if (claims.isEmpty) {
        debugPrint('⚠️ getClaims(force=$actuallyForce) → empty');
      }
      return claims;
    } on fb.FirebaseAuthException catch (e) {
      // Tolerate transient token states; return empty for callers to handle softly.
      debugPrint('⚠️ getClaims auth error (${e.code})');
      return const {};
    } catch (_) {
      return const {};
    }
  }

  // ── membership/session endpoints ────────────────────────────
  Future<AuthUser> checkUserStatus({
    String? email,
    String? phoneNumber,
    bool useCache = true,
  }) async {
    final t = DevTrace('check-user-status', context: {'tenant': tenantId});
    final cleanedEmail = _clean(email).toLowerCase();
    final cleanedPhone = _clean(phoneNumber);

    t.log(
      'input',
      add: {'email': cleanedEmail, 'phone': cleanedPhone, 'useCache': useCache},
    );

    if (cleanedEmail.isEmpty && cleanedPhone.isEmpty) {
      t.done('arg-error');
      throw ArgumentError('Either email or phoneNumber must be provided.');
    }

    if (useCache) {
      final cached = _getCachedStatus(
        email: cleanedEmail.isNotEmpty ? cleanedEmail : null,
        phoneNumber: cleanedPhone.isNotEmpty ? cleanedPhone : null,
      );
      if (cached != null) {
        t.done('cache-hit ${cached.status.name} uid=${cached.uid}');
        return cached;
      }
    }

    final token = await _tokens.tryGetToken();
    final uri = _routes.checkUserStatus();
    t.log('POST', add: {'uri': uri.toString(), 'tokenPresent': token != null});

    final resp = await _dio.postUri(
      uri,
      data: {
        if (cleanedEmail.isNotEmpty) 'email': cleanedEmail,
        if (cleanedPhone.isNotEmpty) 'phoneNumber': cleanedPhone,
      },
      options: Options(
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      ),
    );

    final json = jsonDecode(jsonEncode(resp.data)) as Map<String, dynamic>;
    final user = AuthUser.fromJson(json);
    _cacheStatus(user, email: cleanedEmail, phoneNumber: cleanedPhone);
    t.done('ok → ${user.status.name} uid=${user.uid}');
    return user;
  }

  /// Ask server to sync claims. Returns a **non-forced** snapshot of claims.
  /// Schedules a delayed forced ID-token refresh (non-blocking).
  Future<Map<String, dynamic>> syncClaimsAndRefresh() async {
    final t = DevTrace('sync-claims', context: {'tenant': tenantId});
    final uri = _routes.syncClaims();

    // If Firebase user is momentarily null (web rehydration), skip the call.
    if (_auth.currentUser == null) {
      t.done('no-fbUser → skip');
      return const <String, dynamic>{};
    }

    // 1) Server sync (403/404 tolerated while promotion settles)
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

    // 2) Read current claims without forcing (don’t drop session on web)
    Map<String, dynamic> claims = const {};
    try {
      claims = await getClaims(force: false);
      _logClaimsBrief(claims, prefix: '✅ Claims sync requested (no force)');
    } catch (e) {
      t.log('claims-read-soft-fail', add: {'err': e.toString()});
    }

    // 3) Delayed, best-effort force refresh (non-blocking)
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
        // user-token-expired: do nothing; caller flows are soft now.
        t.log('delayed-refresh-autherr', add: {'code': e.code});
      } catch (e) {
        t.log('delayed-refresh-error', add: {'err': e.toString()});
      }
    });

    t.done('ok (no-force)');
    return claims;
  }

  /// Softly ensure the tenant claim matches the selected tenant.
  /// Never throws; attempts to self-heal in the background and returns
  /// the most recent claims snapshot available.
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

    // Nudge server & schedule a silent refresh; do not block or throw.
    unawaited(() async {
      try {
        await syncClaimsAndRefresh();
        // Give web a moment to rehydrate, then soft re-read.
        await Future<void>.delayed(const Duration(seconds: 2));
        await getClaims(force: false);
      } catch (_) {
        // best-effort only
      }
    }());

    _logClaimsBrief(
      before,
      prefix:
          '⚠️ Tenant claim mismatch (claim=$beforeTenant, selected=$expectedTenantId) — continuing soft',
    );
    return before;
  }

  /// Backend membership precheck.
  Future<bool> isTenantMemberEmail(
    String email, {
    bool allowInvitedForInviteFlow = false,
  }) async {
    final cleaned = _normalizeEmail(email);
    if (cleaned.isEmpty) return false;

    try {
      final cached = _getCachedStatus(email: cleaned);
      final user = cached ?? await checkUserStatus(email: cleaned);
      final st = user.status;
      final ok = allowInvitedForInviteFlow
          ? (st.isActive || st.isInvited)
          : st.isActive;
      debugPrint(
        '✅ isTenantMemberEmail verdict (tenant=$tenantId email=$cleaned status=${st.name}) → $ok',
      );
      return ok;
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 404) {
        debugPrint(
          'ℹ️ isTenantMemberEmail: 404 not a member (tenant=$tenantId, $cleaned)',
        );
        return false;
      }
      debugPrint(
        '🔴 isTenantMemberEmail backend error: ${e.message} status=$code',
      );
      return false;
    } catch (e) {
      debugPrint('🔴 isTenantMemberEmail error: $e');
      return false;
    }
  }
}
