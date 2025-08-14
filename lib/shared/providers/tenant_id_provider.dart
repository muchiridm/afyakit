// lib/shared/providers/tenant_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Decides the tenant from:
/// 1. URL query (?tenant=...)  — useful for local testing
/// 2. Hostname/domain          — used in production
/// 3. Fallback to `danabtmc`
String resolveTenantId() {
  final uri = Uri.base;

  // 1️⃣ Query parameter override
  final queryTenant = uri.queryParameters['tenant'];
  if (queryTenant != null && queryTenant.trim().isNotEmpty) {
    return queryTenant.trim().toLowerCase();
  }

  // 2️⃣ Domain-based routing
  final host = uri.host.toLowerCase();
  if (host.contains('afyakit')) return 'afyakit';
  if (host.contains('dawapap')) return 'dawapap';
  if (host.contains('danabtmc')) return 'danabtmc';

  // 3️⃣ Safe fallback
  return 'afyakit'; // Default tenant
}

/// Globally available current tenant id.
final tenantIdProvider = Provider<String>((ref) => resolveTenantId());
