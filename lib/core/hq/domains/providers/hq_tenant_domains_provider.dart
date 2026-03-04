// lib/core/hq/domains/providers/hq_tenant_domains_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/hq/domains/models/domain_binding.dart';
import 'package:afyakit/core/hq/domains/services/tenant_domain_service.dart';

/// Fetch-once list of domains for a tenant (HQ/admin).
/// Refresh by `ref.invalidate(hqTenantDomainsProvider(tenantId))`.
final hqTenantDomainsProvider = FutureProvider.autoDispose
    .family<List<DomainBinding>, String>((ref, tenantId) async {
      final svc = await ref.watch(tenantDomainServiceProvider.future);
      return svc.listTenantDomains(tenantId.trim().toLowerCase());
    });
