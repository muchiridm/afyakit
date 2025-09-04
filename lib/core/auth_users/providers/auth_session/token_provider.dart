import 'package:afyakit/core/auth_users/services/login_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Infra-level token access (no engines).
/// Uses Firebase-only LoginService for session hydration + token fetch.
final tokenProvider = Provider<TokenProvider>((ref) {
  final loginSvc = ref.read(loginServiceFirebaseOnlyProvider);
  return TokenProvider(loginSvc);
});

class AuthTokenException implements Exception {
  final String message;
  AuthTokenException(this.message);
  @override
  String toString() => 'AuthTokenException: $message';
}

class TokenProvider {
  final LoginService _login;
  TokenProvider(this._login);

  /// Ensures a valid Firebase ID token is returned or throws
  Future<String> getToken({bool forceRefresh = true}) async {
    final token = await tryGetToken(forceRefresh: forceRefresh);
    if (token == null || token.isEmpty) {
      debugPrint('❌ TokenProvider.getToken → Missing token');
      throw AuthTokenException('Missing or invalid Firebase ID token');
    }
    debugPrint('🔐 TokenProvider.getToken → Token length: ${token.length}');
    return token;
  }

  /// Tries to get token; returns null if it fails
  Future<String?> tryGetToken({bool forceRefresh = false}) async {
    final hasUser = await _ensureUser();
    if (!hasUser) return null;

    try {
      final token = await _login.getIdToken(forceRefresh: forceRefresh);
      if (token != null) {
        debugPrint('✅ TokenProvider.tryGetToken → Token retrieved');
      }
      return token;
    } catch (e) {
      debugPrint('❌ TokenProvider.tryGetToken → Error: $e');
      return null;
    }
  }

  /// Gets decoded claims or null if unavailable
  Future<Map<String, dynamic>?> getDecodedClaims({
    bool forceRefresh = false,
  }) async {
    final hasUser = await _ensureUser();
    if (!hasUser) return null;

    try {
      // If caller wants freshest, force-refresh the ID token first.
      if (forceRefresh) {
        await _login.getIdToken(forceRefresh: true);
      }

      final user = _login.currentUser ?? fb.FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final tr = await user.getIdTokenResult(false);
      final claims = Map<String, dynamic>.from(tr.claims ?? const {});
      debugPrint(
        '📜 TokenProvider.getDecodedClaims → '
        '${claims.isEmpty ? "No claims" : claims}',
      );
      return claims;
    } catch (e) {
      debugPrint('❌ TokenProvider.getDecodedClaims → Error: $e');
      return null;
    }
  }

  /// Retrieve a single claim
  Future<T?> getClaim<T>(String key) async {
    final claims = await getDecodedClaims();
    final value = claims?[key] as T?;
    value == null
        ? debugPrint('❌ TokenProvider.getClaim → "$key" not found')
        : debugPrint('🔎 TokenProvider.getClaim → "$key" = $value');
    return value;
  }

  /// Like [getClaim] but throws if not found
  Future<T> getRequiredClaim<T>(String key) async {
    final value = await getClaim<T>(key);
    if (value == null) {
      debugPrint('🚫 TokenProvider.getRequiredClaim → Missing "$key"');
      throw AuthTokenException('Missing required claim: "$key"');
    }
    return value;
  }

  /// Ensure Firebase user is hydrated
  Future<bool> _ensureUser() async {
    await _login.waitForUser();
    final user = _login.currentUser ?? fb.FirebaseAuth.instance.currentUser;
    return user != null;
  }
}
