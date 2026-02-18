// lib/hq/domains/services/domain_tenant_resolver.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';

String resolveTenantSlug({String defaultSlug = 'afyakit'}) {
  if (!kIsWeb) return defaultSlug;

  final uri = Uri.base;

  final q = (uri.queryParameters['tenant'] ?? '').trim().toLowerCase();
  if (q.isNotEmpty) return q;

  return defaultSlug;
}

/// Strict resolver via Firestore /domains/{host}.
/// Only returns a tenant if the domain is active + verified.
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

  final host = uri.host.trim().toLowerCase();

  // 2) local dev → don't hit /domains
  const localHosts = {'localhost', '127.0.0.1', '0.0.0.0'};
  if (localHosts.contains(host)) {
    return resolveTenantSlug(defaultSlug: defaultSlug);
  }

  // 3) real host → check /domains/{host}
  final firestore = db ?? FirebaseFirestore.instance;
  try {
    final snap = await firestore.collection('domains').doc(host).get();
    final data = snap.data();
    if (data == null) return resolveTenantSlug(defaultSlug: defaultSlug);

    final active = data['active'] != false; // default true
    final verified = data['verified'] == true;

    if (!active || !verified) {
      // Domain exists but not eligible → do NOT route tenant by it.
      return resolveTenantSlug(defaultSlug: defaultSlug);
    }

    final tenantSlug = (data['tenantSlug'] ?? '')
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
