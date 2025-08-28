// lib/shared/providers/token_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import the service that exposes firebaseOnly provider
import 'package:afyakit/core/auth_users/services/user_operations_service.dart';

/// Infra-level token access (no engines).
/// Uses a Firebase-only UserOperationsService to avoid dependency cycles.
final tokenProvider = Provider<TokenProvider>((ref) {
  final ops = ref.read(firebaseOnlyUserOpsProvider);
  return TokenProvider(ops);
});

class AuthTokenException implements Exception {
  final String message;
  AuthTokenException(this.message);
  @override
  String toString() => 'AuthTokenException: $message';
}

class TokenProvider {
  final UserOperationsService _ops;
  TokenProvider(this._ops);

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
      final token = await _ops.getIdToken(forceRefresh: forceRefresh);
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
      if (forceRefresh) {
        await _ops.refreshToken();
      }
      final claims = await _ops.getClaims(); // throws if no user
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
    await _ops.waitForUser();
    final user = await _ops.getCurrentUser();
    return user != null;
  }
}
