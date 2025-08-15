// lib/users/providers/auth_users_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/users/models/auth_user_model.dart';
import 'package:afyakit/users/providers/user_engine_providers.dart'; // authUserEngineProvider
import 'package:afyakit/shared/types/result.dart';

final authUsersProvider = FutureProvider.autoDispose<List<AuthUser>>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  _log('📥 [authUsers] loading for tenant=$tenantId');

  // ⬇️ authUserEngineProvider is a FutureProvider.family — pass tenantId and await .future
  final engine = await ref.watch(authUserEngineProvider(tenantId).future);

  final res = await engine.all();

  // ⬇️ Ensure all paths return
  if (res is Ok<List<AuthUser>>) {
    final users = res.value;
    _log('✅ [authUsers] ${users.length} users');
    return users;
  } else if (res is Err<List<AuthUser>>) {
    _log('❌ [authUsers] load failed: ${res.error.message}');
    return <AuthUser>[];
  }

  // Safety net (shouldn’t hit)
  _log('⚠️ [authUsers] unexpected result type');
  return <AuthUser>[];
});

void _log(String msg) {
  if (kDebugMode) debugPrint(msg);
}
