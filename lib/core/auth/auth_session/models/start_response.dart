import 'package:afyakit/shared/utils/utils.dart';

class StartResponse {
  const StartResponse({
    required this.ok,
    required this.throttled,
    required this.attemptId,
    required this.expiresInSec,
    this.channel,
    this.maskedTo,
    this.code,
    this.clientAction,
  });

  final bool ok;
  final bool throttled;
  final String? attemptId;
  final int? expiresInSec;

  final String? channel;
  final String? maskedTo;

  /// e.g. EMAIL_REQUIRED, invalid-request, NOT_VERIFIED
  final String? code;

  /// e.g. collect_email, firebase_sms
  final String? clientAction;

  bool get hasAttempt => (attemptId ?? '').trim().isNotEmpty;

  String get codeNorm => (code ?? '').trim().toUpperCase();
  String get clientActionNorm => (clientAction ?? '').trim().toLowerCase();
  String get channelNorm => (channel ?? '').trim().toLowerCase();

  bool get requiresFirebaseSmsClientAction {
    // Server-driven flag wins
    if (clientActionNorm == 'firebase_sms') return true;
    // Backward compatibility: channel == sms
    return channelNorm == 'sms';
  }

  bool get requiresCollectEmail {
    // Keep this robust: if server says collect_email + EMAIL_REQUIRED => do it
    return clientActionNorm == 'collect_email' && codeNorm == 'EMAIL_REQUIRED';
  }

  static String? _s(Object? v) {
    final s = v is String ? v.trim() : null;
    return (s == null || s.isEmpty) ? null : s;
  }

  static int? _i(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  factory StartResponse.fromJson(JsonMap j) {
    return StartResponse(
      ok: j['ok'] == true,
      throttled: j['throttled'] == true,
      attemptId: _s(j['attemptId']),
      expiresInSec: _i(j['expiresInSec']),
      channel: _s(j['channel']),
      maskedTo: _s(j['maskedTo']),
      // accept both {code} and {error}
      code: _s(j['code'] ?? j['error']),
      clientAction: _s(j['clientAction']),
    );
  }
}
