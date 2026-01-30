class StartResponse {
  const StartResponse({
    required this.ok,
    required this.throttled,
    required this.attemptId,
    required this.expiresInSec,
    this.channel,
    this.maskedTo,
  });

  final bool ok;
  final bool throttled;
  final String? attemptId;
  final int? expiresInSec;

  // ✅ NEW
  final String? channel; // "sms" | "email"
  final String? maskedTo; // "+2547***01" or "m***@domain.com"
}
