// lib/hq/users/tenant_users_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/auth/auth_user/services/user_profile_service.dart';

/// Admin-only: list users in the current tenant
final tenantUsersProvider = FutureProvider.autoDispose<List<AuthUser>>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  final svc = await ref.watch(userProfileServiceProvider(tenantId).future);
  return svc.listTenantUsers();
});
