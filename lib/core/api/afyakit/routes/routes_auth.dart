part of 'routes.dart';

extension AfyaKitAuthRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 🔐 Public auth (tenant-scoped; no auth header)
  // ─────────────────────────────────────────────

  /// Token-gated membership check (used *after* Firebase login).
  /// NOTE: This requires Authorization: Bearer <idToken>.
  Uri checkUserStatus() => _uri('auth_login/check-user-status');

  /// ✅ NEW: single entry point — backend chooses SMS vs Email OTP.
  ///
  /// Request body:
  ///   { method: "auto", phoneNumber: "+254...", codeLength?: 6 }
  ///
  /// Response:
  ///   { ok: true, throttled?, attemptId?, expiresInSec?, channel?: "sms"|"email", maskedTo? }
  Uri autoStart() => _uri('auth_login/otp/start');

  /// Legacy explicit starts (keep for older builds).
  Uri smsStart() => _uri('auth_login/sms/start');
  Uri emailStart() => _uri('auth_login/email/start');

  /// Shared verify (works for SMS + Email + verify_email).
  Uri otpVerify() => _uri('auth_login/otp/verify');

  // ─────────────────────────────────────────────
  // 👤 Auth Session (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  Uri getCurrentUser() => _uri('auth/session/me');
  Uri syncClaims() => _uri('auth/session/sync-claims');
}
