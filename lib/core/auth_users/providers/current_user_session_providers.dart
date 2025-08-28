import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/core/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/core/auth_users/user_operations/controllers/session_controller.dart';
import 'package:afyakit/core/auth_users/models/auth_user_model.dart';

void _log(String msg) {
  if (kDebugMode) debugPrint(msg);
}

/// Session-backed current app user (AuthUser)
final currentUserProvider = Provider<AsyncValue<AuthUser?>>((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  final async = ref.watch(sessionControllerProvider(tenantId));
  async.when(
    data: (u) => _log(
      u == null
          ? '👻 [currentUser] none'
          : '✅ [currentUser] ${u.email} / ${u.uid} (tenant=$tenantId)',
    ),
    loading: () => _log('⏳ [currentUser] loading… tenant=$tenantId'),
    error: (e, _) => _log('❌ [currentUser] error: $e (tenant=$tenantId)'),
  );
  return async;
});

/// Convenience future to await session readiness quickly.
final currentUserFutureProvider = FutureProvider<AuthUser?>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final ctrl = ref.read(sessionControllerProvider(tenantId).notifier);
  await ctrl.ensureReady();
  return ctrl.currentUser;
});
