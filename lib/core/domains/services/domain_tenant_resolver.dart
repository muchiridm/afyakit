// lib/core/domains/services/domain_tenant_resolver.dart

// Resolves legacy hostname bindings for web bootstrap.
// Global /domains/{host} owns only tenantId/appId; app binding owns state.
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:cloud_firestore/cloud_firestore.dart';

String resolveTenantId({required String defaultId}) {
  if (!kIsWeb) return defaultId;
  final uri = Uri.base;
  // Explicit overrides are development-only; never let public URL queries
  // control the tenant selected in production.
  if (kDebugMode) {
    final override = (uri.queryParameters['tenant'] ?? '').trim().toLowerCase();
    if (override.isNotEmpty) return override;
  }
  return defaultId;
}

Future<String> resolveTenantIdAsync({
  required String defaultId,
  FirebaseFirestore? db,
}) async {
  if (!kIsWeb) return defaultId;
  final uri = Uri.base;
  if (kDebugMode) {
    final override = (uri.queryParameters['tenant'] ?? '').trim().toLowerCase();
    if (override.isNotEmpty) return override;
  }
  final host = uri.host.trim().toLowerCase();
  const localHosts = {'localhost', '127.0.0.1', '0.0.0.0'};
  if (localHosts.contains(host) || host.isEmpty) return defaultId;

  final firestore = db ?? FirebaseFirestore.instance;
  try {
    final indexSnap = await firestore.collection('domains').doc(host).get();
    final index = indexSnap.data();
    if (index == null) return defaultId;
    final tenantId = (index['tenantId'] ?? '').toString().trim().toLowerCase();
    final appId = (index['appId'] ?? '').toString().trim().toLowerCase();
    if (tenantId.isEmpty || appId.isEmpty) return defaultId;

    final bindingSnap = await firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('apps')
        .doc(appId)
        .collection('domains')
        .doc(host)
        .get();
    final binding = bindingSnap.data();
    if (binding != null) {
      return binding['active'] == true && binding['verified'] == true
          ? tenantId
          : defaultId;
    }
    // Temporary legacy compatibility: only until global-domain migration ends.
    return index['active'] != false && index['verified'] == true
        ? tenantId
        : defaultId;
  } catch (_) {
    // Firestore rules may deny browser reads. The default tenant is the safe
    // fallback; test this path under the deployed Firestore rules.
    return defaultId;
  }
}
