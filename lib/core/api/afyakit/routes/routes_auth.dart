// lib/core/api/afyakit/routes/routes_auth.dart

part of 'routes.dart';

extension AfyaKitAuthRoutes on AfyaKitRoutes {
  // ═════════════════════════════════════════════
  // Public login
  // /api/:tenantId/auth/login/*
  // ═════════════════════════════════════════════

  Uri otpStart() => _uri('auth/login/otp/start');

  Uri otpVerify() => _uri('auth/login/otp/verify');

  Uri emailStart() => _uri('auth/login/email/start');

  // ═════════════════════════════════════════════
  // Authenticated session
  // /api/:tenantId/auth/session/*
  // ═════════════════════════════════════════════

  Uri getCurrentUser() => _uri('auth/session/me');

  /// Register or enrol the Firebase-authenticated phone user
  /// as an ordinary member of the selected tenant/app.
  ///
  /// POST /api/:tenantId/auth/session/register
  ///
  /// Requires:
  /// - Valid Firebase ID token.
  /// - Firebase-verified phone identity.
  /// - Active tenant/application.
  /// - X-App-Id header supplied by AfyaKitClient.
  ///
  /// Registration never grants staff roles.
  Uri registerMember() => _uri('auth/session/register');

  Uri syncClaims() => _uri('auth/session/sync-claims');

  Uri sessionRecoverAccount() => _uri('auth/session/recover-account');

  // ═════════════════════════════════════════════
  // Tenant auth users
  // /api/:tenantId/auth/users
  // ═════════════════════════════════════════════

  Uri getAllUsers({String? search, int? limit}) => _uri(
    'auth/users',
    query: {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (limit != null) 'limit': '$limit',
    },
  );

  Uri createUser() => _uri('auth/users');

  Uri getUserById(String uid) => _authUser(uid);

  Uri updateUser(String uid) => _authUser(uid);

  Uri deleteUser(String uid) => _authUser(uid);

  // ─────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────

  Uri _authUser(String uid) => _uri('auth/users/${_seg(uid)}');
}
