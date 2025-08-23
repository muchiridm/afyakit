import 'package:afyakit/features/auth_users/user_manager/extensions/auth_user_x.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/features/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/features/auth_users/user_operations/controllers/session_controller.dart';
import 'package:afyakit/features/auth_users/models/auth_user_model.dart';
import 'package:afyakit/features/auth_users/user_manager/controllers/user_manager_controller.dart';
// ✅ add this import
import 'package:afyakit/features/auth_users/user_operations/services/user_operations_service.dart';

final currentUserProvider = Provider<AsyncValue<AuthUser?>>((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  final async = ref.watch(sessionControllerProvider(tenantId));
  async.when(
    data: (u) => _log(
      u == null
          ? '👻 [currentUser] No session user'
          : '✅ [currentUser] ${u.email} / ${u.uid} (tenant=$tenantId)',
    ),
    loading: () => _log('⏳ [currentUser] loading... tenant=$tenantId'),
    error: (e, _) => _log('❌ [currentUser] error: $e (tenant=$tenantId)'),
  );
  return async;
});

final currentUserFutureProvider = FutureProvider<AuthUser?>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final ctrl = ref.read(sessionControllerProvider(tenantId).notifier);
  await ctrl.ensureReady();
  return ctrl.currentUser;
});

final currentAuthUserProvider = FutureProvider.autoDispose<AuthUser?>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);

  // Make sure session hydrated
  await ref.watch(currentUserFutureProvider.future);

  Future<AuthUser?> fetch({required bool verbose}) async {
    final fbUser = fb.FirebaseAuth.instance.currentUser;
    if (fbUser == null) {
      _log('🛡 [currentAuthUser] no fbUser (tenant=$tenantId)');
      return null;
    }
    final token = await fbUser.getIdTokenResult(true);
    final claims = Map<String, dynamic>.from(token.claims ?? const {});
    final claimTenant = (claims['tenantId'] ?? claims['tenant'])?.toString();
    final claimRole = (claims['role'] ?? '').toString();
    final claimSuper = claims['superadmin'] ?? claims['superAdmin'] ?? false;

    if (verbose) {
      _log(
        '🛡 [currentAuthUser] start tenant=$tenantId uid=${fbUser.uid} email=${fbUser.email}',
      );
      _log(
        '🛡 [currentAuthUser] claims: tenantId=$claimTenant role=$claimRole '
        'superadmin=$claimSuper keys=${(claims.keys.toList()..sort()).join(",")}',
      );
    }

    final ctrl = ref.read(userManagerControllerProvider.notifier);
    final fetched = await ctrl.getUserById(fbUser.uid);
    if (fetched == null) {
      if (verbose) {
        _log(
          '🛡 [currentAuthUser] fetched=null for tenant=$tenantId uid=${fbUser.uid}',
        );
      }
      return null;
    }

    final mergedClaims = <String, dynamic>{
      ...(fetched.claims ?? {}),
      ...claims,
    };
    final result = fetched.copyWith(claims: mergedClaims);
    _log(
      '🛡 [currentAuthUser] OK tenant=$tenantId uid=${result.uid} '
      'status=${result.status} role=${result.role}',
    );
    return result;
  }

  // First attempt (verbose)
  final first = await fetch(verbose: true);
  if (first != null) return first;

  // Auto-heal when claim tenant != selected tenant
  final fbUser = fb.FirebaseAuth.instance.currentUser;
  final token = await fbUser?.getIdTokenResult();
  final claims = Map<String, dynamic>.from(token?.claims ?? const {});
  final claimTenant = (claims['tenantId'] ?? claims['tenant'])?.toString();

  if (claimTenant != null && claimTenant != tenantId) {
    _log(
      '🛠️ [currentAuthUser] claim-tenant ($claimTenant) != selected tenant ($tenantId); '
      'ensuring tenant claim & refreshing…',
    );

    try {
      // 🔑 Use userOperationsService to sync claims for this tenant
      final ops = await ref.read(
        userOperationsServiceProvider(tenantId).future,
      );
      await ops.ensureTenantClaimSelected(
        tenantId,
        reason: 'currentAuthUser auto-heal',
      );
    } catch (e) {
      _log('💥 ensureTenantClaimSelected failed: $e');
    }

    // Retry once (quiet)
    final second = await fetch(verbose: false);
    if (second != null) {
      _log('🛠️ [currentAuthUser] recovered after claim sync');
      return second;
    }
  }

  _log(
    '🛡 [currentAuthUser] No tenant membership; denying access (tenant=$tenantId)',
  );
  return null;
});

final currentUserValueProvider = Provider<AuthUser?>((ref) {
  final auth = ref.watch(currentAuthUserProvider);
  return auth.maybeWhen(data: (u) => u, orElse: () => null);
});

final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(currentUserValueProvider)?.uid,
);

final canAccessAdminPanelProvider = Provider<bool>((ref) {
  final u = ref.watch(currentUserValueProvider);
  return u?.canAccessAdminPanel ?? false;
});

final currentRoleLabelProvider = Provider<String?>((ref) {
  final u = ref.watch(currentUserValueProvider);
  return u?.effectiveRole.name;
});

void _log(String msg) {
  if (kDebugMode) debugPrint(msg);
}
