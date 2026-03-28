part of 'routes.dart';

extension AfyaKitAuthRoutes on AfyaKitRoutes {
  Uri autoStart() => _uri('auth_login/otp/start');

  Uri emailStart() => _uri('auth_login/email/start');

  Uri otpVerify() => _uri('auth_login/otp/verify');

  Uri getCurrentUser() => _uri('auth/session/me');
  Uri syncClaims() => _uri('auth/session/sync-claims');

  Uri sessionRecoverAccount() => _uri('auth/session/recover-account');
}
