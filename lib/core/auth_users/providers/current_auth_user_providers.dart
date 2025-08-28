import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/hq/core/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/controllers/auth_user_controller.dart';
import 'package:afyakit/core/auth_users/services/user_operations_service.dart';
import 'package:afyakit/core/auth_users/providers/current_user_session_providers.dart';

void _log(String msg) {
  if (kDebugMode) debugPrint(msg);
}

final currentAuthUserProvider = FutureProvider.autoDispose<AuthUser?>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);

  // ensure session is hydrated
  await ref.watch(currentUserFutureProvider.future);

  Future<AuthUser?> fetch({
    required bool verbose,
    bool forceRefreshToken = true,
  }) async {
    final fbUser = fb.FirebaseAuth.instance.currentUser;
    if (fbUser == null) {
      if (verbose) _log('🛡 [currentAuthUser] no fbUser (tenant=$tenantId)');
      return null;
    }

    final token = await fbUser.getIdTokenResult(forceRefreshToken);
    final tokenClaims = Map<String, dynamic>.from(token.claims ?? const {});
    if (verbose) {
      final keys = (tokenClaims.keys.toList()..sort()).join(',');
      _log(
        '🛡 [currentAuthUser] uid=${fbUser.uid} email=${fbUser.email} tenant=$tenantId',
      );
      _log('🛡 [currentAuthUser] claim keys: $keys');
    }

    final um = ref.read(authUserControllerProvider.notifier);
    final doc = await um.getUserById(fbUser.uid);
    if (doc == null) {
      if (verbose) _log('🛡 [currentAuthUser] no AuthUser doc');
      return null;
    }

    // doc claims override token claims
    final merged = <String, dynamic>{...tokenClaims, ...(doc.claims ?? {})};
    return doc.copyWith(claims: merged);
  }

  // 1st pass (fresh token, verbose)
  final first = await fetch(verbose: true, forceRefreshToken: true);
  if (first != null) return first;

  // Heal mismatched tenant claim
  final fbUser = fb.FirebaseAuth.instance.currentUser;
  final token = await fbUser?.getIdTokenResult(false);
  final claimTenant = (token?.claims?['tenantId'] ?? token?.claims?['tenant'])
      ?.toString();

  if (claimTenant != null && claimTenant != tenantId) {
    _log(
      '🛠️ [currentAuthUser] claim-tenant=$claimTenant != selected=$tenantId → syncing',
    );
    try {
      final ops = await ref.read(
        userOperationsServiceProvider(tenantId).future,
      );
      await ops.ensureTenantClaimSelected(tenantId, reason: 'auto-heal');
    } catch (e) {
      _log('💥 ensureTenantClaimSelected failed: $e');
    }
    // retry quietly (token refresh optional)
    final second = await fetch(verbose: false, forceRefreshToken: false);
    if (second != null) {
      _log('🛠️ [currentAuthUser] recovered after claim sync');
      return second;
    }
  }

  _log('🛡 [currentAuthUser] no tenant membership (tenant=$tenantId)');
  return null;
});

/// Quick access to the actual value (or null).
final currentUserValueProvider = Provider<AuthUser?>((ref) {
  final auth = ref.watch(currentAuthUserProvider);
  return auth.maybeWhen(data: (u) => u, orElse: () => null);
});
