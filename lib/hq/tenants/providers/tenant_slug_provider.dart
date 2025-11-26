// lib/hq/tenants/providers/tenant_slug_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/tenants/services/tenant_resolver.dart';

const _defaultTenant = 'afyakit';

/// tenant slug provider
/// priority:
/// 1) --dart-define=TENANT=...
/// 2) URL/host resolver (resolveTenantSlugV2)
/// 3) _defaultTenant
final tenantSlugProvider = Provider<String>((ref) {
  // 1) CLI / build-time override
  const fromDefine = String.fromEnvironment('TENANT', defaultValue: '');
  if (fromDefine.trim().isNotEmpty) {
    return fromDefine.trim().toLowerCase();
  }

  return resolveTenantSlug(defaultSlug: _defaultTenant);
});
