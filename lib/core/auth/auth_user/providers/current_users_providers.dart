// lib/core/auth/auth_user/providers/current_users_providers.dart

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

/// Reactive Firebase user; null on sign-out.
final firebaseUserProvider = StreamProvider<fb.User?>((ref) {
  return fb.FirebaseAuth.instance.authStateChanges();
});

/// Read-only projection of the canonical SessionController.
/// No independent /auth/session/me request and no additional Dio client.
/// Retains FutureProvider<...> to preserve existing callers' AsyncValue API.
final currentUserProvider = FutureProvider.autoDispose<AuthUser?>((ref) async {
  final tenantId = ref.watch(tenantIdProvider).trim().toLowerCase();
  final appId = ref.watch(appIdProvider).trim().toLowerCase();

  // Await initial Firebase stream emission rather than treating `loading`
  // as a signed-out user. Re-evaluates on sign-in and sign-out.
  final firebaseUser = await ref.watch(firebaseUserProvider.future);
  if (firebaseUser == null) return null;

  final session = ref.watch(sessionControllerProvider(tenantId));
  if (session.isLoading && !session.hasValue) return null;
  if (session.hasError && !session.hasValue) {
    throw session.error!;
  }

  final user = session.valueOrNull;
  if (user == null || user.uid != firebaseUser.uid) return null;
  if (user.tenantId.trim().toLowerCase() != tenantId) return null;

  // SessionController already resolves forApp; repeat here only to ensure
  // the projection respects a changed active application context.
  return user.forApp(appId);
});

final currentUserValueProvider = Provider<AuthUser?>((ref) {
  return ref.watch(currentUserProvider).valueOrNull;
});

final userDisplayNameProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserValueProvider);
  if (user == null) return null;
  final displayName = (user.displayName ?? '').trim();
  if (displayName.isNotEmpty) return displayName;
  final full = user.computedDisplayName.trim();
  return full.isEmpty ? null : full;
});
