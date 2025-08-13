// lib/shared/providers/tenant_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Decide the tenant from URL query (?tenant=...) or host name.
/// Safe default is `danabtmc` (tenant #1).
String resolveTenantId() {
  final uri = Uri.base;

  // Query param override is handy for local testing:
  final q = uri.queryParameters['tenant'];
  if (q != null && q.trim().isNotEmpty) return q.trim().toLowerCase();

  // Domain-based routing in production:
  final host = uri.host.toLowerCase();
  if (host.contains('dawapap')) return 'dawapap';
  if (host.contains('danabtmc')) return 'danabtmc';

  // Fallback
  return 'danabtmc';
}

/// Globally available current tenant id.
final tenantIdProvider = Provider<String>((ref) => resolveTenantId());
