// lib/hq/tenants/v2/providers/tenant_slug_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/tenants/v2/services/tenant_resolver_v2.dart';

const _defaultTenant = 'afyakit';

/// v2 tenant slug provider
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

  // 2) normal v2 resolution (URL / host)
  return resolveTenantSlugV2(defaultSlug: _defaultTenant);
});
