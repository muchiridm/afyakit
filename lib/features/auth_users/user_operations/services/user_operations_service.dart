import 'dart:async';
import 'dart:convert';

import 'package:afyakit/shared/api/api_client.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:afyakit/features/auth_users/models/auth_user_model.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userOperationsServiceProvider =
    FutureProvider.family<UserOperationsService, String>((ref, tenantId) async {
      final tokens = ref.read(tokenProvider);
      final svc = await UserOperationsService.createWithBackend(
        tenantId: tenantId,
        tokenProvider: tokens,
        withAuth: true,
      );
      // Optional: log base + attempt to align claim with selected tenant here.
      // await svc.ensureTenantClaimSelected(tenantId, reason: 'userOperationsServiceProvider init');
      return svc;
    });

final firebaseOnlyUserOpsProvider = Provider<UserOperationsService>(
  (_) => UserOperationsService.firebaseOnly(),
);

class UserOperationsService {
  final FirebaseAuth _auth;
  final ApiClient? _client; // optional (backend-enabled)
  final ApiRoutes? _routes; // optional (backend-enabled)
  final TokenProvider? _tokens; // optional (backend-enabled)

  UserOperationsService._(this._auth, this._client, this._routes, this._tokens);

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
    if (kDebugMode) {
      debugPrint('🔗 ApiClient Base URL: ${client.baseUrl}');
    }
    return UserOperationsService._(
      FirebaseAuth.instance,
      client,
      routes,
      tokenProvider,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
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

  // Extract active tenant from ID token claims
  String? _tenantFromClaims(Map<String, dynamic> claims) {
    final t = claims['tenantId'] ?? claims['tenant'];
    return t?.toString();
  }

  // Pretty log claims (tenant/role/superadmin + keys)
  void _logClaimsBrief(Map<String, dynamic> claims, {String? prefix}) {
    final keys = (claims.keys.toList()..sort()).join(',');
    final tenant = _tenantFromClaims(claims);
    final role = claims['role'];
    final superadmin = claims['superadmin'] ?? claims['superAdmin'];
    debugPrint(
      '${prefix ?? '🔍 Claims'} tenantId=$tenant role=$role superadmin=$superadmin keys=$keys',
    );
  }

  Future<Map<String, dynamic>> _getFreshClaims() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('❌ Firebase Auth token missing');
    final res = await user.getIdTokenResult(true);
    return Map<String, dynamic>.from(res.claims ?? const {});
  }

  // ─────────────────────────────────────────────────────────────
  // 🔐 Sign In / Sign Out (Firebase client)
  // ─────────────────────────────────────────────────────────────
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = EmailHelper.normalize(email);
    final credential = await _auth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    debugPrint('🔓 Signed in as: ${credential.user?.email}');
    return credential;
  }

  Future<void> signOut() async {
    final email = _auth.currentUser?.email;
    await _auth.signOut();
    debugPrint('🔒 User signed out: $email');
  }

  // ─────────────────────────────────────────────────────────────
  // 🔁 Session / Hydration (Firebase client)
  // ─────────────────────────────────────────────────────────────
  Future<bool> isLoggedIn() async => _auth.currentUser != null;

  Future<void> waitForUser() async {
    final completer = Completer<void>();
    late final StreamSubscription<User?> sub;

    sub = _auth.authStateChanges().listen((user) async {
      debugPrint(
        user != null
            ? '✅ Firebase user restored: ${user.email}'
            : '👻 No Firebase user',
      );
      if (!completer.isCompleted) completer.complete();
      await sub.cancel();
    });

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => debugPrint('⏳ FirebaseAuth hydration timed out.'),
    );
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
  // 🔑 Tokens + Claims (Firebase client)
  // ─────────────────────────────────────────────────────────────
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('❌ Cannot get token — no user signed in');
      return null;
    }
    final token = await user.getIdToken(forceRefresh);
    debugPrint('🪙 Token fetched (length: ${token?.length ?? 0})');
    return token;
  }

  Future<void> refreshToken() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('❌ Cannot refresh — no user signed in');
    final token = await user.getIdToken(true);
    debugPrint('🔄 Token force-refreshed (length: ${token?.length ?? 0})');
  }

  Future<Map<String, dynamic>> getClaims({int retries = 5}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('❌ Firebase Auth token missing');

    for (int i = 0; i < retries; i++) {
      final tokenResult = await user.getIdTokenResult(true);
      final claims = Map<String, dynamic>.from(tokenResult.claims ?? const {});
      debugPrint('🔐 Attempt ${i + 1} → Claims: $claims');
      if (claims.isNotEmpty) return claims;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    throw Exception('❌ Failed to load Firebase claims after $retries retries');
  }

  Future<void> logClaims() async {
    try {
      final claims = await getClaims();
      _logClaimsBrief(claims, prefix: '🔍 Current user claims');
    } catch (e) {
      debugPrint('❌ Failed to log claims: $e');
    }
  }

  Future<User?> getCurrentUser() async => _auth.currentUser;

  // ─────────────────────────────────────────────────────────────
  // 🛰️ Backend session ops (tenant-scoped)
  // ─────────────────────────────────────────────────────────────

  /// Check if a user exists / status via backend directory (tenant-scoped base URL).
  /// Public endpoint — token is optional; we pass it if available.
  Future<AuthUser> checkUserStatus({String? email, String? phoneNumber}) async {
    final routes = _requireBackend(_routes, 'checkUserStatus');
    final tokens = _requireBackend(_tokens, 'checkUserStatus');

    final cleanedEmail = _clean(email).toLowerCase();
    final cleanedPhone = _clean(phoneNumber);

    if (cleanedEmail.isEmpty && cleanedPhone.isEmpty) {
      throw ArgumentError('Either email or phoneNumber must be provided.');
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
    return AuthUser.fromJson(json);
  }

  /// 🔁 Hit /auth/session/sync-claims (tenant-scoped) then force-refresh the ID token.
  /// Returns the refreshed claims.
  Future<Map<String, dynamic>> syncClaimsAndRefresh() async {
    final routes = _requireBackend(_routes, 'syncClaimsAndRefresh');
    final uri = routes.syncClaims();
    debugPrint('🔁 Syncing claims via $uri');
    final res = await _dio.postUri(uri);
    if ((res.statusCode ?? 0) ~/ 100 != 2) {
      debugPrint(
        '🚫 sync-claims non-2xx status=${res.statusCode} data=${res.data}',
      );
    }
    await _auth.currentUser?.getIdToken(true);
    final claims = await _getFreshClaims();
    _logClaimsBrief(claims, prefix: '✅ Claims synced & refreshed');
    return claims;
  }

  /// Ensure the active tenant in the token matches [tenantId].
  /// If mismatched, calls sync-claims for this tenant and refreshes the token, then verifies.
  /// Returns the final claims. Throws if still mismatched.
  Future<Map<String, dynamic>> ensureTenantClaimSelected(
    String tenantId, {
    String? reason,
  }) async {
    final before = await _getFreshClaims();
    final beforeTenant = _tenantFromClaims(before);

    debugPrint(
      '🧭 ensureTenantClaimSelected($tenantId)'
      '${reason != null ? ' reason=$reason' : ''} '
      '→ currentClaimTenant=$beforeTenant',
    );

    if (beforeTenant == tenantId) {
      _logClaimsBrief(before, prefix: '✅ Tenant claim already correct');
      return before;
    }

    debugPrint(
      '🛠️ Tenant claim mismatch ($beforeTenant → $tenantId). '
      'Syncing claims for tenant…',
    );
    final after = await syncClaimsAndRefresh();
    final afterTenant = _tenantFromClaims(after);

    if (afterTenant != tenantId) {
      debugPrint(
        '❌ Tenant claim still mismatched after sync '
        '(expected=$tenantId, got=$afterTenant).',
      );
      throw StateError(
        'Active tenant claim mismatch after sync. expected=$tenantId got=$afterTenant',
      );
    }

    _logClaimsBrief(after, prefix: '✅ Tenant claim corrected');
    return after;
  }

  // ─────────────────────────────────────────────────────────────
  // 📧 Password reset (choose path)
  // ─────────────────────────────────────────────────────────────
  Future<void> sendPasswordResetEmail(
    String email, {
    ActionCodeSettings? actionCodeSettings,
    bool viaBackend = false,
  }) async {
    final cleanedEmail = EmailHelper.normalize(email);
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
        final reason = res.data is Map
            ? (res.data as Map)['error']
            : 'Unknown error';
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

  Future<bool> isEmailRegistered(String email) async {
    final cleaned = EmailHelper.normalize(email);
    if (cleaned.isEmpty) return false;

    try {
      // Prefer backend (tenant-aware) if we have routes/tokens.
      if (_routes != null && _client != null && _tokens != null) {
        try {
          final user = await checkUserStatus(email: cleaned);
          // If backend returns a user object, consider it registered.
          return user.uid.isNotEmpty;
        } on DioException catch (e) {
          final code = e.response?.statusCode ?? 0;
          // Common case: API returns 404 for unknown user.
          if (code == 404) return false;
          // Other HTTP errors should surface (or be logged).
          if (kDebugMode) {
            debugPrint(
              '🔴 isEmailRegistered backend error: ${e.message} '
              'status=$code data=${e.response?.data}',
            );
          }
          rethrow;
        }
      }

      // Fallback: Firebase check (not tenant-aware).
      final methods = await _auth.fetchSignInMethodsForEmail(cleaned);
      return methods.isNotEmpty;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ isEmailRegistered error: $e');
      // Be conservative on unexpected errors.
      return false;
    }
  }
}
