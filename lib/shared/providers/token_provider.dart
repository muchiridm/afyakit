import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/users/services/firebase_auth_service.dart';

/// Provides access to Firebase ID token and decoded claims via AuthService
final tokenProvider = Provider<TokenProvider>((ref) {
  final auth = ref.read(firebaseAuthServiceProvider);
  return TokenProvider(auth);
});

/// Custom exception to isolate Firebase internals
class AuthTokenException implements Exception {
  final String message;
  AuthTokenException(this.message);

  @override
  String toString() => 'AuthTokenException: $message';
}

class TokenProvider {
  final FirebaseAuthService auth;

  TokenProvider(this.auth);

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
    final user = await _waitForUser();
    if (user == null) return null;

    try {
      final token = await user.getIdToken(forceRefresh);
      debugPrint('✅ TokenProvider.tryGetToken → Token retrieved');
      return token;
    } catch (e) {
      debugPrint('❌ TokenProvider.tryGetToken → Error: $e');
      return null;
    }
  }

  /// Gets all decoded claims or null if unavailable
  Future<Map<String, dynamic>?> getDecodedClaims({
    bool forceRefresh = false,
  }) async {
    final user = await _waitForUser();
    if (user == null) return null;

    try {
      final result = await user.getIdTokenResult(forceRefresh);
      final claims = result.claims ?? {};
      debugPrint(
        '📜 TokenProvider.getDecodedClaims → ${claims.isEmpty ? "No claims" : claims}',
      );
      return claims;
    } catch (e) {
      debugPrint('❌ TokenProvider.getDecodedClaims → Error: $e');
      return null;
    }
  }

  /// Tries to retrieve a single claim of type T
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

  /// Internal retry to ensure user is hydrated before proceeding
  Future<fb.User?> _waitForUser() async {
    await auth.waitForUser();
    return await auth.getCurrentUser();
  }
}
