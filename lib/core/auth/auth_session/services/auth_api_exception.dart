class AuthApiException implements Exception {
  AuthApiException({
    required this.statusCode,
    required this.code,
    required this.userMessage,
    this.debugMessage,
  });

  final int statusCode;
  final String code;
  final String userMessage;
  final String? debugMessage;

  @override
  String toString() => 'AuthApiException($statusCode, $code)';
}

String friendlyAuthMessage({
  required int status,
  required String code,
  String? email,
  String? phone,
}) {
  final c = code.trim().toUpperCase();
  final e = (email ?? '').trim();
  final p = (phone ?? '').trim();

  switch (c) {
    case 'EMAIL_PHONE_MISMATCH':
      return "That email doesn’t match the phone number you entered. "
          "Go back and confirm your phone number, or try a different email.";

    case 'INVALID_OTP':
    case 'INVALID_CODE':
    case 'CODE_INVALID':
      return 'That code is incorrect. Please try again.';

    case 'OTP_EXPIRED':
    case 'CODE_EXPIRED':
      return 'That code has expired. Tap “Resend code” and try again.';

    case 'ATTEMPT_NOT_FOUND':
      return 'That code session is no longer valid. Tap “Resend code”.';

    case 'THROTTLED':
    case 'TOO_MANY_REQUESTS':
      return 'Please wait a bit before requesting another code.';

    case 'EMAIL_REQUIRED':
      // This is control-flow in your Somalia branch; you generally won't show it as an error.
      return 'Email is required to continue.';
  }

  // Generic fallbacks by HTTP status
  if (status == 401) {
    return 'That code is invalid or expired. Please request a new code.';
  }
  if (status == 409) {
    // 409 is often “conflict / mismatch / already-used”
    if (e.isNotEmpty || p.isNotEmpty) {
      return 'That information doesn’t match our records. Please double-check and try again.';
    }
    return 'That request conflicts with your account state. Please try again.';
  }
  if (status == 400) {
    return 'Please double-check your details and try again.';
  }

  return 'Something went wrong. Please try again.';
}
