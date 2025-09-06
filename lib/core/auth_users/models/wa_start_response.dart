// Simple response model for WA start
class WaStartResponse {
  final bool ok;
  final bool throttled;
  final String? attemptId;
  final int? expiresInSec;
  const WaStartResponse({
    required this.ok,
    this.throttled = false,
    this.attemptId,
    this.expiresInSec,
  });
}
