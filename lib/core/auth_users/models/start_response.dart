// Simple response model for WA start
class StartResponse {
  final bool ok;
  final bool throttled;
  final String? attemptId;
  final int? expiresInSec;
  const StartResponse({
    required this.ok,
    this.throttled = false,
    this.attemptId,
    this.expiresInSec,
  });
}
