// lib/core/auth_users/services/user_operations_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:afyakit/api/api_client.dart';
import 'package:afyakit/api/api_routes.dart';
import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/extensions/user_status_x.dart';
import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────

/// Always backend-enabled for the given tenantId.
/// If you need Firebase-only behavior, use [firebaseOnlyUserOpsProvider].
final userOperationsServiceProvider =
    FutureProvider.family<UserOperationsService, String>((ref, tenantId) async {
      final tokens = ref.read(tokenProvider);
      return UserOperationsService.createWithBackend(
        tenantId: tenantId,
        tokenProvider: tokens,
        withAuth: true,
      );
    });

/// Explicit Firebase-only service (no backend).
final firebaseOnlyUserOpsProvider = Provider<UserOperationsService>(
  (_) => UserOperationsService.firebaseOnly(),
);

class _Timed<T> {
  final T value;
  final DateTime at;
  static const _statusTtl = Duration(seconds: 8);
  _Timed(this.value) : at = DateTime.now();
  bool get fresh => DateTime.now().difference(at) < _statusTtl;
}

// ─────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────

class UserOperationsService {
  UserOperationsService._(
    this._auth,
    this._client,
    this._routes,
    this._tokens, {
    String? tenantId,
  }) : _tenantId = tenantId;

  // Core deps
  final FirebaseAuth _auth;
  final ApiClient? _client; // present when backend-enabled
  final ApiRoutes? _routes; // present when backend-enabled
  final TokenProvider? _tokens; // present when backend-enabled
  final String? _tenantId;

  bool get hasBackend => _client != null && _routes != null && _tokens != null;
  String? get expectedTenantId => _tenantId;

  /// Firebase-only (no backend calls)
  factory UserOperationsService.firebaseOnly() =>
      UserOperationsService._(FirebaseAuth.instance, null, null, null);

  /// Firebase + backend (tenant-scoped base URL)
  static Future<UserOperationsService> createWithBackend({
    required String tenantId,
    required TokenProvider tokenProvider,
    bool withAuth = true,
  }) async {
    final client = await ApiClient.create(
      tenantId: tenantId,
      tokenProvider: tokenProvider,
      withAuth: withAuth,
    );
    final routes = ApiRoutes(tenantId);
    if (kDebugMode) debugPrint('🔗 ApiClient Base URL: ${client.baseUrl}');
    return UserOperationsService._(
      FirebaseAuth.instance,
      client,
      routes,
      tokenProvider,
      tenantId: tenantId,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────

  Dio get _dio {
    final c = _client?.dio;
    if (c == null) {
      throw StateError(
        'UserOperationsService: backend call requested but service was created without ApiClient/Routes. '
        'Use createWithBackend(...) for backend features.',
      );
    }
    return c;
  }

  T _requireBackend<T>(T? v, String fn) {
    if (v == null) {
      throw StateError(
        'UserOperationsService.$fn requires backend (ApiClient/ApiRoutes/TokenProvider). '
        'Construct with createWithBackend(...).',
      );
    }
    return v;
  }

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

  Future<T> _retry<T>({
    required int maxAttempts,
    required Duration baseDelay,
    required Future<T> Function(int attempt) run,
    bool Function(Object error)? retryIf,
  }) async {
    Object? lastErr;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await run(attempt);
      } catch (e) {
        lastErr = e;
        final ok = retryIf?.call(e) ?? false;
        if (!ok || attempt == maxAttempts) rethrow;
        final waitMs = baseDelay.inMilliseconds * math.pow(2, attempt - 1);
        await Future.delayed(Duration(milliseconds: waitMs.toInt()));
      }
    }
    // Should never reach here
    // ignore: only_throw_errors
    throw lastErr!;
  }

  // ─────────────────────────────────────────────────────────────
  // Tiny status cache to avoid double-hitting check-user-status
  // ─────────────────────────────────────────────────────────────

  final Map<String, _Timed<AuthUser>> _statusCache = {};

  String _statusKey({String? email, String? phoneNumber}) =>
      '${(email ?? '').trim().toLowerCase()}|${(phoneNumber ?? '').trim()}';

  AuthUser? getCachedUserStatus({String? email, String? phoneNumber}) {
    final k = _statusKey(email: email, phoneNumber: phoneNumber);
    final hit = _statusCache[k];
    return (hit != null && hit.fresh) ? hit.value : null;
  }

  void _cacheUserStatus(AuthUser u, {String? email, String? phoneNumber}) {
    final k = _statusKey(email: email, phoneNumber: phoneNumber);
    _statusCache[k] = _Timed(u);
  }

  // ─────────────────────────────────────────────────────────────
  // Strict membership precheck (backend only)
  // ─────────────────────────────────────────────────────────────

  Future<bool> isTenantMemberEmail(
    String email, {
    bool allowInvitedForInviteFlow = false,
  }) async {
    final cleaned = _normalizeEmail(email);
    if (cleaned.isEmpty) return false;

    if (!hasBackend) {
      debugPrint(
        '⚠️ isTenantMemberEmail: no backend (blocking) tenant=$_tenantId',
      );
      return false;
    }

    try {
      final cached = getCachedUserStatus(email: cleaned);
      final user = cached ?? await checkUserStatus(email: cleaned);
      final st = user.status;
      final ok = allowInvitedForInviteFlow
          ? (st.isActive || st.isInvited)
          : st.isActive;

      debugPrint(
        '✅ isTenantMemberEmail verdict (tenant=$_tenantId email=$cleaned status=${st.name}) → $ok',
      );
      return ok;
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 404) {
        debugPrint(
          'ℹ️ isTenantMemberEmail: 404 not a member (tenant=$_tenantId, $cleaned)',
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

  // ─────────────────────────────────────────────────────────────
  // Sign In / Out
  // ─────────────────────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalized = _normalizeEmail(email);
    final cred = await _auth.signInWithEmailAndPassword(
      email: normalized,
      password: password,
    );
    debugPrint('🔓 Signed in as: ${cred.user?.email}');
    return cred;
  }

  Future<void> signOut() async {
    _statusCache.clear(); // avoid stale precheck results
    final email = _auth.currentUser?.email;
    await _auth.signOut();
    debugPrint('🔒 User signed out: $email');
  }

  // ─────────────────────────────────────────────────────────────
  // Session / Hydration
  // ─────────────────────────────────────────────────────────────

  Future<bool> isLoggedIn() async => _auth.currentUser != null;

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

  Future<void> waitForUserSignIn({
    Duration timeout = const Duration(seconds: 6),
    Duration checkEvery = const Duration(milliseconds: 200),
  }) async {
    final sw = Stopwatch()..start();
    while (_auth.currentUser == null) {
      if (sw.elapsed > timeout) {
        throw TimeoutException(
          '⏰ User not signed in after ${timeout.inSeconds}s',
        );
      }
      await Future.delayed(checkEvery);
    }
    debugPrint('✅ Firebase user ready after ${sw.elapsedMilliseconds}ms');
  }

  // ─────────────────────────────────────────────────────────────
  // Tokens + Claims
  // ─────────────────────────────────────────────────────────────

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('❌ Cannot get token — no user signed in');
      return null;
    }
    final token = await user.getIdToken(forceRefresh);
    debugPrint('🪙 Token fetched (length: ${token!.length})');
    return token;
  }

  Future<void> refreshToken() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('❌ Cannot refresh — no user signed in');
    final token = await user.getIdToken(true);
    debugPrint('🔄 Token force-refreshed (length: ${token!.length})');
  }

  /// Get claims, optionally forcing token refresh; retries with small backoff if empty.
  Future<Map<String, dynamic>> getClaims({
    int retries = 5,
    bool force = true,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('❌ Firebase Auth token missing');

    return _retry<Map<String, dynamic>>(
      maxAttempts: math.max(1, retries),
      baseDelay: const Duration(milliseconds: 250),
      retryIf: (_) => true,
      run: (attempt) async {
        final tokenResult = await user.getIdTokenResult(force);
        final claims = Map<String, dynamic>.from(
          tokenResult.claims ?? const {},
        );
        debugPrint('🔐 Attempt $attempt (force=$force) → Claims: $claims');
        if (claims.isEmpty) throw StateError('claims-empty');
        return claims;
      },
    );
  }

  Future<void> logClaims({bool force = true}) async {
    try {
      final claims = await getClaims(force: force);
      _logClaimsBrief(claims, prefix: '🔍 Current user claims');
    } catch (e) {
      debugPrint('❌ Failed to log claims: $e');
    }
  }

  Future<void> forceRefreshIdToken() async {
    await fb.FirebaseAuth.instance.currentUser?.getIdToken(true);
  }

  // ─────────────────────────────────────────────────────────────
  // Backend session ops (tenant-scoped)
  // ─────────────────────────────────────────────────────────────

  /// Checks if a user exists/active for this tenant.
  /// Set [useCache]=false to bypass the short-lived memory cache.
  Future<AuthUser> checkUserStatus({
    String? email,
    String? phoneNumber,
    bool useCache = true,
  }) async {
    final routes = _requireBackend(_routes, 'checkUserStatus');
    final tokens = _requireBackend(_tokens, 'checkUserStatus');

    final cleanedEmail = _clean(email).toLowerCase();
    final cleanedPhone = _clean(phoneNumber);
    if (cleanedEmail.isEmpty && cleanedPhone.isEmpty) {
      throw ArgumentError('Either email or phoneNumber must be provided.');
    }

    if (useCache) {
      final cached = getCachedUserStatus(
        email: cleanedEmail.isNotEmpty ? cleanedEmail : null,
        phoneNumber: cleanedPhone.isNotEmpty ? cleanedPhone : null,
      );
      if (cached != null) {
        debugPrint(
          '🧠 (cache) checkUserStatus → ${cached.email}/${cached.uid}',
        );
        return cached;
      }
    }

    final token = await tokens.tryGetToken();
    final uri = routes.checkUserStatus();

    debugPrint('📡 Checking user status: $cleanedEmail / $cleanedPhone');
    debugPrint('🔐 Auth token present: ${token != null}');

    final response = await _dio.postUri(
      uri,
      data: {
        if (cleanedEmail.isNotEmpty) 'email': cleanedEmail,
        if (cleanedPhone.isNotEmpty) 'phoneNumber': cleanedPhone,
      },
      options: Options(
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      ),
    );

    final json = jsonDecode(jsonEncode(response.data)) as Map<String, dynamic>;
    final user = AuthUser.fromJson(json);
    _cacheUserStatus(user, email: cleanedEmail, phoneNumber: cleanedPhone);
    return user;
  }

  /// POST /auth/session/sync-claims → force-refresh ID token → return refreshed claims.
  Future<Map<String, dynamic>> syncClaimsAndRefresh() async {
    final routes = _requireBackend(_routes, 'syncClaimsAndRefresh');
    final uri = routes.syncClaims();

    // ensure we have a recent token before the POST
    await _auth.currentUser?.getIdToken(true);

    Future<void> doPost() => _dio.postUri(uri);

    await _retry<void>(
      maxAttempts: 2,
      baseDelay: const Duration(milliseconds: 200),
      retryIf: (e) {
        if (e is DioException) {
          final sc = e.response?.statusCode ?? 0;
          return sc == 401 || sc == 403;
        }
        if (e is FirebaseAuthException) {
          return e.code == 'user-token-expired' ||
              e.code == 'requires-recent-login';
        }
        return false;
      },
      run: (attempt) async {
        try {
          await doPost();
        } on DioException catch (e) {
          // Refresh on auth errors and retry once
          final sc = e.response?.statusCode ?? 0;
          if (sc == 401 || sc == 403) {
            await _auth.currentUser?.getIdToken(true);
            rethrow;
          }
          rethrow;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-token-expired' ||
              e.code == 'requires-recent-login') {
            await _auth.currentUser?.getIdToken(true);
            rethrow;
          }
          rethrow;
        }
      },
    );

    // Pick up the fresh claims after backend wrote them
    await forceRefreshIdToken();
    final claims = await getClaims(force: true);
    _logClaimsBrief(claims, prefix: '✅ Claims synced & refreshed');
    return claims;
  }

  /// Ensure the ID token’s tenant claim matches [tenantId]. If not, sync and verify.
  Future<Map<String, dynamic>> ensureTenantClaimSelected(
    String tenantId, {
    String? reason,
  }) async {
    final before = await getClaims(force: false);
    final beforeTenant = _tenantFromClaims(before);
    debugPrint(
      '🧭 ensureTenantClaimSelected($tenantId)${reason != null ? ' reason=$reason' : ''} '
      '→ currentClaimTenant=$beforeTenant',
    );

    if (beforeTenant == tenantId) {
      _logClaimsBrief(before, prefix: '✅ Tenant claim already correct');
      return before;
    }

    debugPrint(
      '🛠️ Tenant claim mismatch ($beforeTenant → $tenantId). Syncing…',
    );

    final after = await syncClaimsAndRefresh();
    final afterTenant = _tenantFromClaims(after);

    if (afterTenant != tenantId) {
      debugPrint(
        '❌ Tenant claim still mismatched after sync (expected=$tenantId, got=$afterTenant).',
      );
      throw StateError(
        'Active tenant claim mismatch after sync. expected=$tenantId got=$afterTenant',
      );
    }

    _logClaimsBrief(after, prefix: '✅ Tenant claim corrected');
    return after;
  }

  // ─────────────────────────────────────────────────────────────
  // Password reset
  // ─────────────────────────────────────────────────────────────

  Future<void> sendPasswordResetEmail(
    String email, {
    ActionCodeSettings? actionCodeSettings,
    bool viaBackend = false,
  }) async {
    final cleanedEmail = _normalizeEmail(email);
    if (cleanedEmail.isEmpty) {
      throw ArgumentError('❌ Email is required');
    }

    if (viaBackend) {
      final routes = _requireBackend(
        _routes,
        'sendPasswordResetEmail(viaBackend:true)',
      );
      final res = await _dio.postUri(
        routes.sendPasswordResetEmail(),
        data: {'email': cleanedEmail},
      );
      if ((res.statusCode ?? 0) ~/ 100 != 2) {
        final reason = res.data is Map ? (res.data as Map)['error'] : 'Unknown';
        throw Exception('❌ Failed to send reset email: $reason');
      }
      debugPrint('✅ (Backend) Password reset email sent to $cleanedEmail');
      return;
    }

    await _auth.sendPasswordResetEmail(
      email: cleanedEmail,
      actionCodeSettings: actionCodeSettings,
    );
    debugPrint('✅ (Client) Password reset email sent to: $cleanedEmail');
  }

  /// Tenant-aware registration probe.
  Future<bool> isEmailRegistered(String email) async {
    final cleaned = _normalizeEmail(email);
    if (cleaned.isEmpty) return false;

    try {
      if (_routes != null && _client != null && _tokens != null) {
        try {
          final user = await checkUserStatus(email: cleaned);
          return user.uid.isNotEmpty;
        } on DioException catch (e) {
          final code = e.response?.statusCode ?? 0;
          if (code == 404) return false;
          if (kDebugMode) {
            debugPrint(
              '🔴 isEmailRegistered backend error: ${e.message} status=$code data=${e.response?.data}',
            );
          }
          rethrow;
        }
      }
      final methods = await _auth.fetchSignInMethodsForEmail(cleaned);
      return methods.isNotEmpty;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ isEmailRegistered error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Back-compat shims
  // ─────────────────────────────────────────────────────────────

  Future<User?> getCurrentUser() async => _auth.currentUser;
}
