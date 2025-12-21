// lib/core/auth_user/providers/current_user_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/core/auth/controllers/session_controller.dart';

import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/core/auth_user/services/user_profile_service.dart';

/// Canonical reactive current user for the selected tenant.
/// This is just a view over SessionController, so logout works instantly.
final currentUserProvider = Provider<AsyncValue<AuthUser?>>((ref) {
  final tenantId = ref.watch(tenantSlugProvider);
  return ref.watch(sessionControllerProvider(tenantId));
});

/// Convenience: plain AuthUser? value (or null) without dealing with AsyncValue.
final currentUserValueProvider = Provider<AuthUser?>((ref) {
  final async = ref.watch(currentUserProvider);
  return async.valueOrNull;
});

/// Display-friendly label
final userDisplayNameProvider = Provider<String?>((ref) {
  final async = ref.watch(currentUserProvider);
  final u = async.valueOrNull;

  if (u == null) return null;
  if (u.displayName.trim().isNotEmpty) return u.displayName.trim();
  return u.phoneNumber;
});

/// List of users in the current tenant (admin use cases)
final tenantUsersProvider = FutureProvider.autoDispose<List<AuthUser>>((
  ref,
) async {
  final tenantId = ref.watch(tenantSlugProvider);
  final svc = await ref.watch(userProfileServiceProvider(tenantId).future);
  return svc.listTenantUsers();
});
