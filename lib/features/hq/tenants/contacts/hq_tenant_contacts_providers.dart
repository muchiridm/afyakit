// lib/features/hq/tenants/contacts/hq_tenant_contacts_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'hq_tenant_contacts_service.dart';

/// First page only. Call the service directly to retrieve additional cursor pages.
final hqTenantContactsProvider = FutureProvider.autoDispose
    .family<HqTenantContactsPage, String>((ref, tenantId) async {
  final service = await ref.watch(hqTenantContactsServiceProvider.future);
  return service.list(tenantId);
});

/// Tenant + account are both essential to uniquely scope this family.
typedef HqContactKey = ({String tenantId, String accountNumber});

final hqTenantContactProvider = FutureProvider.autoDispose
    .family<HqTenantContact, HqContactKey>((ref, key) async {
  final service = await ref.watch(hqTenantContactsServiceProvider.future);
  return service.get(key.tenantId, key.accountNumber);
});

final hqTenantContactDependenciesProvider = FutureProvider.autoDispose
    .family<HqTenantContactDependencies, HqContactKey>((ref, key) async {
  final service = await ref.watch(hqTenantContactsServiceProvider.future);
  return service.dependencies(key.tenantId, key.accountNumber);
});
