// lib/hq/providers/hq_providers.dart
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:afyakit/hq/tenants/tenant_model.dart';
import 'package:afyakit/hq/tenants/tenant_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tenantServiceProvider = Provider((ref) {
  return TenantService(FirebaseFirestore.instance);
});

// simplest: pass-through
final tenantsStreamProvider = StreamProvider.autoDispose<List<Tenant>>((ref) {
  final svc = ref.watch(tenantServiceProvider);
  return svc.streamTenants();
});

// OR, if you want newest-first without relying on Firestore orderBy:
final tenantsStreamProviderSorted = StreamProvider.autoDispose<List<Tenant>>((
  ref,
) {
  final svc = ref.watch(tenantServiceProvider);
  return svc.streamTenants().map((list) {
    final sorted = [...list]
      ..sort(
        (a, b) => (b.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
          a.createdAt?.millisecondsSinceEpoch ?? 0,
        ),
      );
    return sorted;
  });
});
