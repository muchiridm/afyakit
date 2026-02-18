// lib/hq/tenants/providers/tenant_providers.dart

import 'package:afyakit/hq/domains/services/domain_tenant_resolver.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

const _defaultTenant = 'afyakit';

final tenantSlugProvider = Provider<String>((ref) {
  // 1) CLI / build-time override
  const fromDefine = String.fromEnvironment('TENANT', defaultValue: '');
  if (fromDefine.trim().isNotEmpty) {
    return fromDefine.trim().toLowerCase();
  }

  // 2) Domain resolver (web) / fallback
  return resolveTenantSlug(defaultSlug: _defaultTenant);
});
