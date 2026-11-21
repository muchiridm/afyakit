// lib/features/hq/tenants/hq_tenant_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/tenancy/models/tenant_profile.dart';
import 'package:afyakit/features/hq/tenants/tenant_service.dart';

/// HQ tenants list (fetch-once).
/// Refresh by `ref.invalidate(hqTenantsProvider)`.
final hqTenantsProvider = FutureProvider.autoDispose<List<TenantProfile>>((
  ref,
) async {
  final svc = await ref.watch(tenantServiceProvider.future);
  return svc.fetchTenantProfiles();
});

final hqTenantProvider = FutureProvider.autoDispose
    .family<TenantProfile, String>((ref, tenantId) async {
      final svc = await ref.watch(tenantServiceProvider.future);
      return svc.getTenantProfile(tenantId.trim().toLowerCase());
    });
