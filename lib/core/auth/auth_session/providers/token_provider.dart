// lib/core/auth_users/providers/token_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

final tokenProvider = Provider<TokenProvider>((ref) {
  return TokenProvider();
});

class AuthTokenException implements Exception {
  final String message;
  AuthTokenException(this.message);
  @override
  String toString() => 'AuthTokenException: $message';
}

class TokenProvider {
  fb.FirebaseAuth get _auth => fb.FirebaseAuth.instance;

  Future<String> getToken({bool forceRefresh = true}) async {
    final token = await tryGetToken(forceRefresh: forceRefresh);
    if (token == null || token.isEmpty) {
      throw AuthTokenException('Missing Firebase ID token');
    }
    return token;
  }

  Future<String?> tryGetToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      return await user.getIdToken(forceRefresh);
    } catch (e) {
      debugPrint('Token error: $e');
      return null;
    }
  }
}
