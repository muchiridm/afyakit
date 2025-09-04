import 'package:afyakit/api/api_client.dart';
import 'package:afyakit/api/api_routes.dart';
import 'package:afyakit/core/auth_users/providers/auth_session/token_provider.dart';
import 'package:afyakit/shared/utils/dev_trace.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Login (Firebase-only)
final loginServiceFirebaseOnlyProvider = Provider<LoginService>(
  (_) => LoginService.firebaseOnly(),
);

/// Login with backend (only if you need backend password reset)
final loginServiceProvider = FutureProvider.family<LoginService, String>((
  ref,
  tenantId,
) async {
  final api = await ApiClient.create(
    tenantId: tenantId,
    tokenProvider: ref.read(tokenProvider),
    withAuth: true,
  );
  return LoginService.createWithBackend(tenantId: tenantId, client: api);
});

class LoginService {
  LoginService._(this._auth, this._client, this._routes);

  final fb.FirebaseAuth _auth;
  final ApiClient? _client; // optional (only needed for backend reset)
  final ApiRoutes? _routes;

  /// Firebase-only
  factory LoginService.firebaseOnly() =>
      LoginService._(fb.FirebaseAuth.instance, null, null);

  /// Firebase + backend (for backend-driven password reset, etc.)
  static Future<LoginService> createWithBackend({
    required String tenantId,
    required ApiClient client,
  }) async =>
      LoginService._(fb.FirebaseAuth.instance, client, ApiRoutes(tenantId));

  // Expose expected tenantId (engine uses this to enforce claims via SessionService)
  String? get expectedTenantId => _routes?.tenantId;

  // ── sign in/out ─────────────────────────────────────────────
  fb.User? get currentUser => _auth.currentUser;

  Future<fb.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    debugPrint('🔓 Signed in as: ${cred.user?.email}');
    return cred;
  }

  Future<void> signOut() async {
    final email = _auth.currentUser?.email;
    await _auth.signOut();
    debugPrint('🔒 User signed out: $email');
  }

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

  /// Check if email has any sign-in method — nice UX before reset
  Future<bool> isEmailRegistered(String email) async {
    final methods = await _auth.fetchSignInMethodsForEmail(email);
    return methods.isNotEmpty;
  }

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final u = _auth.currentUser;
    return u?.getIdToken(forceRefresh);
  }

  // ── password reset ──────────────────────────────────────────
  Future<void> sendPasswordResetEmail(
    String email, {
    bool viaBackend = false,
  }) async {
    if (!viaBackend) {
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('✅ (Client) Password reset email sent to $email');
      return;
    }
    if (_client == null || _routes == null) {
      throw StateError(
        'LoginService.sendPasswordResetEmail(viaBackend) requires backend.',
      );
    }
    final t = DevTrace('password-reset', context: {'tenant': _routes.tenantId});
    final uri = _routes.sendPasswordResetEmail();
    t.log('POST', add: {'uri': uri.toString()});
    final res = await _client.dio.postUri(uri, data: {'email': email});
    if ((res.statusCode ?? 0) ~/ 100 != 2) {
      final reason = res.data is Map ? (res.data as Map)['error'] : 'Unknown';
      t.done('backend-fail $reason');
      throw Exception('❌ Failed to send reset email: $reason');
    }
    t.done('ok');
    debugPrint('✅ (Backend) Password reset email sent to $email');
  }
}
