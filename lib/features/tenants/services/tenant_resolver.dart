import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Fast, sync resolver (query override → simple host hints → default).
String resolveTenantSlug({String defaultSlug = 'afyakit'}) {
  if (!kIsWeb) return defaultSlug;

  final uri = Uri.base;

  // ?tenant= override (useful for staging)
  final q = (uri.queryParameters['tenant'] ?? '').trim().toLowerCase();
  if (q.isNotEmpty) return q;

  // simple heuristics as a soft fallback
  final host = uri.host.toLowerCase();
  if (host.contains('danab')) return 'danabtmc';
  if (host.contains('dawapap')) return 'dawapap';

  return defaultSlug;
}

/// Strict resolver via Firestore /domains/{host}, with graceful fallback.
Future<String> resolveTenantSlugAsync({
  required String defaultSlug,
  FirebaseFirestore? db,
}) async {
  if (!kIsWeb) return defaultSlug;

  final uri = Uri.base;

  // ?tenant= override
  final q = (uri.queryParameters['tenant'] ?? '').trim().toLowerCase();
  if (q.isNotEmpty) return q;

  // /domains/{host} lookup
  final host = uri.host.toLowerCase();
  final firestore = db ?? FirebaseFirestore.instance;
  try {
    final snap = await firestore.collection('domains').doc(host).get();
    final slug = (snap.data()?['slug'] ?? '').toString().trim();
    if (slug.isNotEmpty) return slug;
  } catch (_) {
    // ignore and fall back
  }

  // fall back to sync heuristic (which itself falls back to default)
  return resolveTenantSlug(defaultSlug: defaultSlug);
}
