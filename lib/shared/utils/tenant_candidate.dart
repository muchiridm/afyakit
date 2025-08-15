// lib/shared/utils/tenant_candidate.dart
String? detectTenantCandidateFromUrl() {
  final uri = Uri.base;

  // 1) ?tenant= override
  final q = uri.queryParameters['tenant'];
  if (q != null && q.trim().isNotEmpty) {
    return q.trim().toLowerCase();
  }

  // 2) Hostname subdomain (e.g. afyakit.example.com -> "afyakit")
  final host = uri.host.toLowerCase();
  if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
    return null; // local dev: require ?tenant= or fallback
  }
  final parts = host.split('.');
  if (parts.length >= 3) {
    // subdomain.domain.tld => take subdomain as candidate
    final sub = parts.first.trim();
    if (sub.isNotEmpty) return sub;
  }
  return null;
}
