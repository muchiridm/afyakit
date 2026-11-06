// lib/core/api/afyakit/routes/routes_auth.dart

part of 'routes.dart';

extension AfyaKitAuthRoutes on AfyaKitRoutes {
  // Public login: POST /api/:tenantId/auth/login/*
  Uri otpStart() => _uri('auth/login/otp/start');

  Uri otpVerify() => _uri('auth/login/otp/verify');

  Uri emailStart() => _uri('auth/login/email/start');

  // Authenticated session: requires a valid Firebase bearer token.
  // GET /api/:tenantId/auth/session/me
  Uri getCurrentUser() => _uri('auth/session/me');

  /// POST /api/:tenantId/auth/session/register
  ///
  /// Enrols the Firebase-authenticated user into the tenant/app as a member.
  /// Requires a Firebase bearer token and the X-App-Id header.
  /// Does not grant staff roles.
  Uri registerMember() => _uri('auth/session/register');

  // Tenant auth users. List/create/update/delete are platform-admin only.
  // GET /api/:tenantId/auth/users
  // The backend currently does not support search/limit filtering.
  Uri getAllUsers() => _uri('auth/users');

  // POST /api/:tenantId/auth/users
  Uri createUser() => _uri('auth/users');

  // GET /api/:tenantId/auth/users/:id
  // The owner may read their own record; other reads require platform admin.
  Uri getUserById(String uid) => _authUser(uid);

  // PATCH /api/:tenantId/auth/users/:id
  Uri updateUser(String uid) => _authUser(uid);

  // DELETE /api/:tenantId/auth/users/:id
  Uri deleteUser(String uid) => _authUser(uid);

  // PUT /api/:tenantId/auth/users/:id/apps/:appId/membership
  Uri setUserAppMembership(String uid, String appId) =>
      _uri('auth/users/${_seg(uid)}/apps/${_seg(appId)}/membership');

  // PUT /api/:tenantId/auth/users/:id/apps/:appId/staff-roles
  Uri setUserAppStaffRoles(String uid, String appId) =>
      _uri('auth/users/${_seg(uid)}/apps/${_seg(appId)}/staff-roles');

  Uri _authUser(String uid) => _uri('auth/users/${_seg(uid)}');
}
