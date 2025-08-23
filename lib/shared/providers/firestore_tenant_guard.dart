// lib/shared/providers/firestore_tenant_guard.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/features/auth_users/user_operations/services/user_operations_service.dart';

final firestoreTenantGuardProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  // react to tenant changes
  final tenantId = ref.watch(tenantIdProvider);
  final ops = await ref.watch(userOperationsServiceProvider(tenantId).future);

  // small grace period to avoid thrash on quick route changes
  final link = ref.keepAlive();
  Timer? purge;
  ref.onCancel(() => purge = Timer(const Duration(seconds: 20), link.close));
  ref.onResume(() => purge?.cancel());

  Future<Map<String, dynamic>> readClaims() async {
    final map = await ops.getClaims();
    if (kDebugMode) debugPrint('🔎 [guard] claims after read: $map');
    return map;
  }

  var tokenClaims = await readClaims();
  final initialTenant =
      (tokenClaims['tenantId'] ?? tokenClaims['tenant']) as String?;
  final isSuper = tokenClaims['superadmin'] == true;

  if (!isSuper && initialTenant != tenantId) {
    debugPrint(
      '🛠 [guard] claimTenant=$initialTenant ≠ selected=$tenantId → syncing…',
    );
    await ops.syncClaimsAndRefresh(); // server sync + token refresh
    tokenClaims = await readClaims();
  }

  final finalTenant =
      (tokenClaims['tenantId'] ?? tokenClaims['tenant']) as String?;
  if (!isSuper && finalTenant != tenantId) {
    throw StateError(
      'Tenant claim mismatch after sync (claim=$finalTenant, selected=$tenantId)',
    );
  }

  debugPrint('✅ [guard] claims ready for tenant=$tenantId (super=$isSuper)');
});
