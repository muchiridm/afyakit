// lib/shared/providers/tenant_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/utils/tenant_candidate.dart';

const _defaultTenantFallback = 'afyakit'; // your safe default

/// Resolves an *active* tenant slug:
/// - uses candidate from URL/host if valid & active
/// - otherwise falls back to first active (alphabetical)
final resolvedTenantFutureProvider = FutureProvider<String>((ref) async {
  final db = FirebaseFirestore.instance;
  final candidate = detectTenantCandidateFromUrl();

  // 1) Try candidate if present
  if (candidate != null) {
    final snap = await db.doc('tenants/$candidate').get();
    final data = snap.data();
    final status = (data?['status'] ?? 'active').toString();
    if (snap.exists && status == 'active') return candidate;
  }

  // 2) Fallback: first active tenant alphabetically by displayName (or slug)
  final q = await db
      .collection('tenants')
      .where('status', isEqualTo: 'active')
      .orderBy(
        'displayName',
      ) // relies on displayName existing; if not, change below
      .limit(1)
      .get();

  if (q.docs.isNotEmpty) {
    return q.docs.first.id; // doc id == slug
  }

  // 3) Final fallback — hardcoded safety net
  return _defaultTenantFallback;
});

/// Convenience wrapper: returns a *string* immediately
/// (falls back to default until async resolve completes)
final tenantIdProvider = Provider<String>((ref) {
  final async = ref.watch(resolvedTenantFutureProvider);
  return async.maybeWhen(
    data: (slug) => slug,
    orElse: () => _defaultTenantFallback,
  );
});
