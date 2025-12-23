import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Fast, sync resolver (query → simple hostname hints → default).
String resolveTenantSlug({String defaultSlug = 'afyakit'}) {
  if (!kIsWeb) return defaultSlug;

  final uri = Uri.base;

  final q = (uri.queryParameters['tenant'] ?? '').trim().toLowerCase();
  if (q.isNotEmpty) return q;

  return defaultSlug;
}

/// Strict resolver via Firestore /domains/{host}, with v2 field names.
/// Still skips localhost.
Future<String> resolveTenantSlugAsync({
  required String defaultSlug,
  FirebaseFirestore? db,
}) async {
  if (!kIsWeb) return defaultSlug;

  final uri = Uri.base;

  // 1) explicit query wins
  final q = (uri.queryParameters['tenant'] ?? '').trim().toLowerCase();
  if (q.isNotEmpty) return q;

  final host = uri.host.toLowerCase();

  // 2) local dev → don't hit /domains
  const localHosts = {'localhost', '127.0.0.1', '0.0.0.0'};
  if (localHosts.contains(host)) {
    return resolveTenantSlug(defaultSlug: defaultSlug);
  }

  // 3) real host → check /domains/{host}
  final firestore = db ?? FirebaseFirestore.instance;
  try {
    final snap = await firestore.collection('domains').doc(host).get();
    // v2 DomainIndex has tenantSlug
    final tenantSlug = (snap.data()?['tenantSlug'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (tenantSlug.isNotEmpty) return tenantSlug;
  } catch (_) {
    // ignore, fall back
  }

  // 4) fallback
  return resolveTenantSlug(defaultSlug: defaultSlug);
}
