// lib/core/api/afyakit/routes/routes_auth.dart

part of 'routes.dart';

extension AfyaKitAuthRoutes on AfyaKitRoutes {
  // Uri checkUserStatus() => _uri('auth_login/check-user-status');

  /// Phone-only entry. Backend returns either:
  /// - email attempt (attemptId), OR
  /// - next=firebase_phone
  Uri autoStart() => _uri('auth_login/otp/start');

  /// Email start (login or verify_email)
  Uri emailStart() => _uri('auth_login/email/start');

  /// Verify BACKEND attempt (email-only now)
  Uri otpVerify() => _uri('auth_login/otp/verify');

  Uri getCurrentUser() => _uri('auth/session/me');
  Uri syncClaims() => _uri('auth/session/sync-claims');
}
