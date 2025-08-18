import 'package:afyakit/users/user_manager/extensions/auth_user_x.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb; // 👈 NEW

import 'package:afyakit/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/users/user_operations/controllers/session_controller.dart';
import 'package:afyakit/users/user_manager/models/auth_user_model.dart';
import 'package:afyakit/users/user_manager/controllers/user_manager_controller.dart'; // 👈 keep

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

/// ─────────────────────────────────────────────────────────────
/// NEW: Real AuthUser (from Firestore/API) + fresh TOKEN claims
/// Token claims override mirrored Firestore claims. This is what
/// you should use for role/permission gating (e.g., isSuperAdmin).
/// ─────────────────────────────────────────────────────────────
final currentAuthUserProvider = FutureProvider.autoDispose<AuthUser?>((
  ref,
) async {
  // 1) Wait for session so we have a uid
  final session = await ref.watch(currentUserFutureProvider.future);
  final uid = session?.uid;
  if (uid == null || uid.isEmpty) return null;

  // 2) Grab a fresh ID token (ensures new claims after promotion)
  final fbUser = fb.FirebaseAuth.instance.currentUser;
  Map<String, dynamic> tokenClaims = const {};
  if (fbUser != null) {
    final token = await fbUser.getIdTokenResult(true);
    tokenClaims = Map<String, dynamic>.from(
      token.claims ?? const <String, dynamic>{},
    );
  }

  // 3) Fetch authoritative user doc (for profile/role/tenant fields)
  final ctrl = ref.read(userManagerControllerProvider.notifier);
  final fetched = await ctrl.getUserById(uid);

  // 4) Merge claims: token wins over any mirrored doc claims
  AuthUser base = fetched ?? session!;
  final existingClaims = Map<String, dynamic>.from(
    base.claims ?? const <String, dynamic>{},
  );
  final mergedClaims = <String, dynamic>{...existingClaims, ...tokenClaims};

  // 5) Return a copy with merged claims
  final result = base.copyWith(claims: mergedClaims);

  _log('🛡 [currentAuthUser] isSuperAdmin=${result.isSuperAdmin}');
  return result;
});

/// Simple nullable value (no loading/error envelope), from the MERGED provider
final currentUserValueProvider = Provider<AuthUser?>((ref) {
  final auth = ref.watch(currentAuthUserProvider);
  return auth.maybeWhen(data: (u) => u, orElse: () => null);
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

/// Optional: tiny convenience to read the current effective role for UI chips.
final currentRoleLabelProvider = Provider<String?>((ref) {
  final u = ref.watch(currentUserValueProvider);
  return u?.effectiveRole.name; // model role wins; superadmin is separate
});

void _log(String msg) {
  if (kDebugMode) debugPrint(msg);
}
