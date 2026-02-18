// lib/core/hq/domains/services/domain_tenant_resolver.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';

String resolveTenantId({required String defaultId}) {
  if (!kIsWeb) return defaultId;

  final uri = Uri.base;
  final q = (uri.queryParameters['tenant'] ?? '').trim().toLowerCase();
  if (q.isNotEmpty) return q;

  return defaultId;
}

/// Strict resolver via Firestore /domains/{host}.
/// Only returns a tenant if the domain is active + verified.
/// Still skips localhost.
Future<String> resolveTenantIdAsync({
  required String defaultId,
  FirebaseFirestore? db,
}) async {
  if (!kIsWeb) return defaultId;

  final uri = Uri.base;

  // 1) explicit query wins
  final q = (uri.queryParameters['tenant'] ?? '').trim().toLowerCase();
  if (q.isNotEmpty) return q;

  final host = uri.host.trim().toLowerCase();

  // 2) local dev → don't hit /domains
  const localHosts = {'localhost', '127.0.0.1', '0.0.0.0'};
  if (localHosts.contains(host)) return defaultId;

  final firestore = db ?? FirebaseFirestore.instance;

  try {
    final snap = await firestore.collection('domains').doc(host).get();
    final data = snap.data();
    if (data == null) return defaultId;

    final active = data['active'] != false; // default true
    final verified = data['verified'] == true;
    if (!active || !verified) return defaultId;

    final tenantId = (data['tenantId'] ?? '').toString().trim().toLowerCase();
    if (tenantId.isNotEmpty) return tenantId;
  } catch (_) {
    // ignore and fall back
  }

  return defaultId;
}
