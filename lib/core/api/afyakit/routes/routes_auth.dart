// lib/core/api/afyakit/routes/routes_auth.dart

part of 'routes.dart';

extension AfyaKitAuthRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 🔐 Public auth (tenant-scoped; no auth header)
  // ─────────────────────────────────────────────

  Uri checkUserStatus() => _uri('auth_login/check-user-status');
  Uri waStart() => _uri('auth_login/wa/start');
  Uri smsStart() => _uri('auth_login/sms/start');
  Uri emailStart() => _uri('auth_login/email/start');
  Uri otpVerify() => _uri('auth_login/otp/verify');

  // ─────────────────────────────────────────────
  // 👤 Auth Session (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  Uri getCurrentUser() => _uri('auth/session/me');
  Uri syncClaims() => _uri('auth/session/sync-claims');
}
