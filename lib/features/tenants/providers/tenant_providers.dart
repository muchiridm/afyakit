// lib/tenants/providers/tenant_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:afyakit/shared/utils/firestore_instance.dart'; // your FireFlex instance/bootstrap
import 'package:afyakit/shared/api/api_client.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:afyakit/features/tenants/providers/tenant_id_provider.dart';

import 'package:afyakit/features/tenants/models/tenant_dtos.dart';
import 'package:afyakit/features/tenants/services/tenant_service.dart';

/// ─────────────────────────────────────────────────────────────
/// API client → TenantService (mutations only: create/update/delete/etc.)
/// ─────────────────────────────────────────────────────────────
final tenantServiceProvider = FutureProvider.autoDispose<TenantService>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  final tokenProv = ref.read(tokenProvider);

  final client = await ApiClient.create(
    tenantId: tenantId,
    tokenProvider: tokenProv,
    withAuth: true,
  );
  final routes = ApiRoutes(tenantId);
  return TenantService(client: client, routes: routes);
});

/// ─────────────────────────────────────────────────────────────
/// Firestore collection (typed) for /tenants
/// ─────────────────────────────────────────────────────────────
final _tenantsRefProvider =
    Provider.autoDispose<CollectionReference<TenantSummary>>((ref) {
      // If your FireFlex wrapper exposes an instance (e.g. `firestore`), use it.
      final db = FirebaseFirestore.instance; // or `firestore` from your wrapper
      return db
          .collection('tenants')
          .withConverter<TenantSummary>(
            fromFirestore: (snap, _) => _tenantFromDoc(snap),
            // We don’t write via Firestore in this layer; API handles mutations.
            toFirestore: (value, _) => <String, dynamic>{},
          );
    });

TenantSummary _tenantFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
  final data = d.data() ?? <String, dynamic>{};
  final m = Map<String, dynamic>.from(data);

  // Ensure slug/id is present for DTO
  m.putIfAbsent('slug', () => d.id);

  // Normalize timestamps for DTO (string ISO is fine)
  final created = m['createdAt'];
  if (created is Timestamp) {
    m['createdAt'] = created.toDate().toIso8601String();
  }

  // Friendly defaults
  m.putIfAbsent('displayName', () => m['name'] ?? d.id);
  m.putIfAbsent('status', () => 'active');
  m.putIfAbsent('primaryColor', () => '#1565C0');

  return TenantSummary.fromJson(m);
}

/// ─────────────────────────────────────────────────────────────
/// Live stream of tenants (Firestore → FireFlex-style reads)
/// ─────────────────────────────────────────────────────────────
final tenantsStreamProvider = StreamProvider.autoDispose<List<TenantSummary>>((
  ref,
) {
  final col = ref.watch(_tenantsRefProvider);
  final query = col.orderBy('createdAt', descending: true);

  return query.snapshots().map(
    (snap) => snap.docs.map((d) => d.data()).toList(),
  );
});

/// Alphabetically sorted by displayName (fallback to slug)
final tenantsStreamProviderSorted =
    StreamProvider.autoDispose<List<TenantSummary>>((ref) {
      final base = ref.watch(tenantsStreamProvider.stream);
      return base.map((list) {
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

/// ─────────────────────────────────────────────────────────────
/// Single tenant (live updates) by slug/doc id
/// ─────────────────────────────────────────────────────────────
final tenantStreamBySlugProvider = StreamProvider.autoDispose
    .family<TenantSummary, String>((ref, slug) {
      final col = ref.watch(_tenantsRefProvider);
      return col.doc(slug).snapshots().map((doc) {
        if (!doc.exists) {
          throw StateError('tenant-not-found');
        }
        return doc.data()!;
      });
    });

/// One-off fetch if you really need a Future (non-live)
final tenantBySlugOnceProvider = FutureProvider.autoDispose
    .family<TenantSummary, String>((ref, slug) async {
      final col = ref.watch(_tenantsRefProvider);
      final doc = await col.doc(slug).get();
      if (!doc.exists) throw StateError('tenant-not-found');
      return doc.data()!;
    });
