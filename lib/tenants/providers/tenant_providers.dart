// lib/hq/providers/hq_providers.dart

import 'package:afyakit/tenants/models/tenant_dtos.dart';
import 'package:afyakit/tenants/services/tenant_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/api/api_client.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/shared/providers/token_provider.dart'; // assumes you expose a TokenProvider via Riverpod
import 'package:afyakit/tenants/providers/tenant_id_provider.dart';

/// Builds a backend-driven TenantService (no Firestore).
/// Uses the current tenantId for base URL scoping and attaches an auth token.
final tenantServiceProvider = FutureProvider.autoDispose<TenantService>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  final tokenProv = ref.read(tokenProvider); // <- your TokenProvider

  final client = await ApiClient.create(
    tenantId: tenantId,
    tokenProvider: tokenProv,
    withAuth: true,
  );
  final routes = ApiRoutes(tenantId);
  return TenantService(client: client, routes: routes);
});

/// Stream of tenants via polling, replacing Firestore snapshots().
final tenantsStreamProvider = StreamProvider.autoDispose<List<TenantSummary>>((
  ref,
) async* {
  final svc = await ref.watch(tenantServiceProvider.future);
  // Default poll interval is defined in the service; override here if you want:
  yield* svc.streamTenants(); // svc.streamTenants(every: Duration(seconds: 8))
});

/// Same stream, but sorted by displayName (then slug) newest-first-ish UI.
/// (We no longer have createdAt on the DTO, so sort lexicographically.)
final tenantsStreamProviderSorted =
    StreamProvider.autoDispose<List<TenantSummary>>((ref) async* {
      final baseStream = ref.watch(tenantsStreamProvider.stream);
      yield* baseStream.map((list) {
        final sorted = [...list]
          ..sort((a, b) {
            final ad = (a.displayName.isEmpty ? a.slug : a.displayName)
                .toLowerCase();
            final bd = (b.displayName.isEmpty ? b.slug : b.displayName)
                .toLowerCase();
            return ad.compareTo(bd);
          });
        return sorted;
      });
    });

/// Optional: fetch a single tenant on demand.
final tenantBySlugProvider = FutureProvider.autoDispose
    .family<TenantSummary, String>((ref, slug) async {
      final svc = await ref.watch(tenantServiceProvider.future);
      return svc.getTenant(slug);
    });
