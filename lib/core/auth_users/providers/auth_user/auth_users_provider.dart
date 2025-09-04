// lib/core/auth_users/providers/auth_users_provider.dart
import 'package:afyakit/core/auth_users/controllers/auth_user/auth_user_engine.dart';
import 'package:afyakit/shared/utils/provider_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/core/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/shared/types/result.dart';

List<AuthUser> _sortedByEmail(List<AuthUser> users) {
  users.sort((a, b) => a.email.toLowerCase().compareTo(b.email.toLowerCase()));
  return users;
}

final authUsersProvider = FutureProvider.autoDispose<List<AuthUser>>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  pLog('📥 [authUsers] loading for tenant=$tenantId');

  final engine = await ref.watch(authUserEngineProvider(tenantId).future);
  final res = await engine.all();

  if (res is Ok<List<AuthUser>>) {
    final users = _sortedByEmail(res.value);
    pLog('✅ [authUsers] ${users.length} users');
    return users;
  }

  pLog(
    '❌ [authUsers] load failed: ${(res as Err<List<AuthUser>>).error.message}',
  );
  return const <AuthUser>[];
});
