import 'package:afyakit/users/extensions/auth_user_x.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/users/controllers/session_controller.dart';
import 'package:afyakit/users/models/auth_user_model.dart';
import 'package:afyakit/users/controllers/auth_user_controller.dart'; // 👈 add

/// UI-friendly: returns AsyncValue<AuthUser?> from the SESSION controller
final currentUserProvider = Provider<AsyncValue<AuthUser?>>((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  final async = ref.watch(sessionControllerProvider(tenantId)); // AsyncValue

  async.when(
    data: (u) => _log(
      u == null
          ? '👻 [currentUser] No AuthUser'
          : '✅ [currentUser] ${u.email} / ${u.uid}',
    ),
    loading: () => _log('⏳ [currentUser] loading...'),
    error: (e, _) => _log('❌ [currentUser] error: $e'),
  );

  return async;
});

/// Imperative/await usage: lets you do `await ref.read(... .future)`
final currentUserFutureProvider = FutureProvider<AuthUser?>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final ctrl = ref.read(sessionControllerProvider(tenantId).notifier);
  await ctrl.ensureReady(); // hydrate if needed
  return ctrl.currentUser; // AuthUser? (SESSION copy)
});

/// Simple nullable value (no loading/error envelope)
final currentUserValueProvider = Provider<AuthUser?>((ref) {
  final async = ref.watch(currentUserProvider);
  return async.asData?.value;
});

/// Small, focused selectors you’ll use everywhere
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(currentUserValueProvider)?.uid,
);

/// Example capability flag (uses your AuthUserX extension)
final canAccessAdminPanelProvider = Provider<bool>((ref) {
  final u = ref.watch(currentUserValueProvider);
  return u?.canAccessAdminPanel ?? false;
});

void _log(String msg) {
  if (kDebugMode) debugPrint(msg);
}

/// ─────────────────────────────────────────────────────────────
/// NEW: Real AuthUser (from Firestore/API), joined by uid
/// Use this for UI role chips/guards instead of `currentUserProvider`.
/// ─────────────────────────────────────────────────────────────

final currentAuthUserProvider = FutureProvider.autoDispose<AuthUser?>((
  ref,
) async {
  // 1) wait for session so we have a uid
  final session = await ref.watch(currentUserFutureProvider.future);
  final uid = session?.uid;
  if (uid == null || uid.isEmpty) return null;

  // 2) fetch the authoritative AuthUser via controller (reads auth_users)
  final ctrl = ref.read(authUserControllerProvider.notifier);
  final user = await ctrl.getUserById(uid);
  return user ?? session; // fallback to session if fetch fails
});

/// Optional: tiny convenience to read the current effective role for UI chips.
final currentRoleLabelProvider = Provider<String?>((ref) {
  final auth = ref.watch(currentAuthUserProvider);
  return auth.maybeWhen(
    data: (u) => u?.effectiveRole.name, // model role wins
    orElse: () => null,
  );
});
