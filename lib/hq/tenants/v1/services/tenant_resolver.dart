// lib/hq/tenants/v1/services/tenant_resolver.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Fast, sync resolver (query override → simple host hints → default).
String resolveTenantSlug({String defaultSlug = 'afyakit'}) {
  if (!kIsWeb) return defaultSlug;

  final uri = Uri.base;

  // 1) explicit ?tenant=… always wins
  final q = (uri.queryParameters['tenant'] ?? '').trim().toLowerCase();
  if (q.isNotEmpty) return q;

  // 2) simple host heuristics (for real domains)
  final host = uri.host.toLowerCase();
  if (host.contains('danab')) return 'danabtmc';
  if (host.contains('dawapap')) return 'dawapap';

  // 3) fallback
  return defaultSlug;
}

/// Strict resolver via Firestore /domains/{host}, with graceful fallback.
/// On localhost/127.0.0.1/0.0.0.0 we **do not** try Firestore domain mapping,
/// because it can force us into another tenant (e.g. dawapap) while the token
/// is still for afyakit → 403 on the backend.
Future<String> resolveTenantSlugAsync({
  required String defaultSlug,
  FirebaseFirestore? db,
}) async {
  if (!kIsWeb) return defaultSlug;

  final uri = Uri.base;

  // 1) explicit ?tenant=… still wins everywhere
  final q = (uri.queryParameters['tenant'] ?? '').trim().toLowerCase();
  if (q.isNotEmpty) return q;

  final host = uri.host.toLowerCase();

  // 2) local dev → DON'T hit Firestore domains
  const localHosts = {'localhost', '127.0.0.1', '0.0.0.0'};
  if (localHosts.contains(host)) {
    // keep old behaviour: use heuristic/default
    return resolveTenantSlug(defaultSlug: defaultSlug);
  }

  // 3) real host → try Firestore /domains/{host}
  final firestore = db ?? FirebaseFirestore.instance;
  try {
    final snap = await firestore.collection('domains').doc(host).get();
    final slug = (snap.data()?['slug'] ?? '').toString().trim();
    if (slug.isNotEmpty) return slug;
  } catch (_) {
    // ignore and fall back
  }

  // 4) fallback to heuristic/default
  return resolveTenantSlug(defaultSlug: defaultSlug);
}
