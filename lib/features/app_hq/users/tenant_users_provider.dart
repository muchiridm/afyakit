import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/core/auth_user/services/user_profile_service.dart';

/// Admin-only: list users in the current tenant
final tenantUsersProvider = FutureProvider.autoDispose<List<AuthUser>>((
  ref,
) async {
  final tenantId = ref.watch(tenantSlugProvider);
  final svc = await ref.watch(userProfileServiceProvider(tenantId).future);
  return svc.listTenantUsers();
});
