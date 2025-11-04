import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:dio/dio.dart' show DioException;

import 'package:afyakit/shared/utils/provider_utils.dart';
import 'package:afyakit/shared/utils/dev_trace.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_user_display.dart';

import 'package:afyakit/hq/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/core/auth_users/models/auth_user_model.dart';

import 'package:afyakit/core/auth_users/controllers/auth_session/session_controller.dart';
import 'package:afyakit/core/auth_users/controllers/auth_user/auth_user_controller.dart';

import 'package:afyakit/core/auth_users/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth_users/utils/auth_claims.dart';
import 'package:afyakit/core/auth_users/utils/auth_errors.dart';

/// ─────────────────────────────────────────────────────────────
/// Helpers
/// ─────────────────────────────────────────────────────────────

Future<fb.User?> _waitForFbUser({
  Duration timeout = const Duration(seconds: 4),
  String where = 'merged',
}) async {
  final t = DevTrace('fb.waitUser ($where)');
  var u = fb.FirebaseAuth.instance.currentUser;
  if (u != null) {
    t.done('already-present uid=${u.uid}');
    return u;
  }
  try {
    u = await fb.FirebaseAuth.instance
        .authStateChanges()
        .where((e) => e != null)
        .first
        .timeout(timeout);
    if (u != null) {
      t.done('present uid=${u.uid}');
    } else {
      t.done('timeout');
    }
  } catch (_) {
    t.done('timeout');
  }
  return u;
}

/// ─────────────────────────────────────────────────────────────
/// 1) Session-backed current app user (AuthUser)
/// ─────────────────────────────────────────────────────────────

final currentUserProvider = Provider<AsyncValue<AuthUser?>>((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  final async = ref.watch(sessionControllerProvider(tenantId));

  async.when(
    data: (u) => pLog(
      u == null
          ? '👻 [currentUser] none'
          : '✅ [currentUser] ${u.email} / ${u.uid} (tenant=$tenantId)',
    ),
    loading: () => pLog('⏳ [currentUser] loading… tenant=$tenantId'),
    error: (e, _) => pLog('❌ [currentUser] error: $e (tenant=$tenantId)'),
  );
  return async;
});

final currentUserFutureProvider = FutureProvider<AuthUser?>((ref) async {
  final tenantId = ref.read(tenantIdProvider);
  final ctrl = ref.read(sessionControllerProvider(tenantId).notifier);
  await ctrl.ensureReady();
  return ctrl.currentUser;
});

/// One-shot fetch of merged doc + claims. Tolerant and never signs out.
Future<AuthUser?> _fetchCurrentAuthUser({
  required Ref ref,
  required String tenantId,
  required bool verbose,
  required bool forceRefreshToken,
}) async {
  final t = DevTrace(
    'currentAuthUser.fetch',
    context: {'tenant': tenantId, 'force': forceRefreshToken},
  );

  final fbUser = await _waitForFbUser(
    timeout: const Duration(seconds: 4),
    where: 'merged',
  );
  if (fbUser == null) {
    t.done('no-fbUser');
    if (verbose) pLog('🛡 [currentAuthUser] no fbUser (tenant=$tenantId)');
    return null;
  }

  // Doc first (so claims flakiness doesn't blank us)
  AuthUser? doc;
  try {
    doc = await ref.read(authUserByIdProvider(fbUser.uid).future);
    if (doc == null) {
      t.done('no-authuser-doc');
      if (verbose) pLog('🛡 [currentAuthUser] no AuthUser doc');
      return null;
    }
    t.log(
      'doc-ok',
      add: {
        'tenant': tenantId,
        'force': forceRefreshToken,
        'attempt': 1,
        'status': doc.status.name,
      },
    );
  } on DioException catch (e) {
    t.log(
      'getUserById dio-error',
      add: {'status': e.response?.statusCode ?? 0},
    );
    if (isSoftAuthError(e)) return null; // 401/403 → soft null
    rethrow;
  }

  // Claims
  Map<String, dynamic> tokenClaims;
  try {
    tokenClaims = await ClaimsUtils.read(force: forceRefreshToken);
    final exp = await fbUser
        .getIdTokenResult(false)
        .then((r) => r.expirationTime);
    final secLeft = exp?.difference(DateTime.now()).inSeconds;
    t.log(
      'token',
      add: {
        'claimsKeys': (tokenClaims.keys.toList()..sort()),
        'expSecLeft': secLeft,
      },
    );
  } on fb.FirebaseAuthException catch (e) {
    if (e.code == 'user-token-expired') {
      t.done('token-expired → soft null');
      if (verbose) pLog('⚠️ [currentAuthUser] token expired → soft null');
      return null;
    }
    t.done('token-exception ${e.code}');
    rethrow;
  }

  t.done('ok status=${doc.status.name}');
  return doc.withMergedClaims(tokenClaims);
}

final currentAuthUserProvider = FutureProvider<AuthUser?>((ref) async {
  final tenantId = ref.read(tenantIdProvider);
  final t = DevTrace('currentAuthUser', context: {'tenant': tenantId});

  // 1) make sure session ran
  await ref.read(currentUserFutureProvider.future);
  t.log('session-hydrated');

  // 2) read session controller + limited flag
  final sessionCtrl = ref.read(sessionControllerProvider(tenantId).notifier);
  final sessionUser = sessionCtrl.currentUser;
  final isLimited = sessionCtrl.isLimited;

  // 👉 invited / cross-tenant / not-active → DO NOT call /auth_users/:id
  if (isLimited) {
    t.done('limited-session → using sessionUser only');
    return sessionUser;
  }

  // 3) normal path (active user → try merged doc)
  final relaxed = await _fetchCurrentAuthUser(
    ref: ref,
    tenantId: tenantId,
    verbose: true,
    forceRefreshToken: false,
  );
  if (relaxed != null) {
    t.done('relaxed-hit ${relaxed.status.name}');
    return relaxed;
  }

  final forced = await _fetchCurrentAuthUser(
    ref: ref,
    tenantId: tenantId,
    verbose: false,
    forceRefreshToken: true,
  );
  if (forced != null) {
    t.done('forced-hit ${forced.status.name}');
    return forced;
  }

  pLog('🛡 [currentAuthUser] unresolved (tolerant null, tenant=$tenantId)');
  t.done('tolerant-null');
  return null;
});

final currentUserValueProvider = Provider<AuthUser?>((ref) {
  final async = ref.watch(currentAuthUserProvider);
  return async.maybeWhen(data: (u) => u, orElse: () => null);
});

/// ─────────────────────────────────────────────────────────────
/// Display helpers
/// ─────────────────────────────────────────────────────────────

final authUserByIdProvider = FutureProvider.autoDispose.family<AuthUser?, String>((
  ref,
  uid,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  if (uid.isEmpty) return null;

  keepAliveFor(ref, const Duration(minutes: 5));

  // 🔎 check session state
  final sessionCtrl = ref.read(sessionControllerProvider(tenantId).notifier);
  if (sessionCtrl.isLimited) {
    // In limited mode, just don’t call backend — return *current* user if it matches
    final me = sessionCtrl.currentUser;
    if (me != null && me.uid == uid) return me;
    DevTrace('authUserById').done('limited-session → soft-null');
    return null;
  }

  final fbUser = await _waitForFbUser(
    timeout: const Duration(seconds: 4),
    where: 'authUserById',
  );
  if (fbUser == null) {
    DevTrace('authUserById').done('no-fbUser → soft-null');
    return null;
  }

  final um = ref.read(authUserControllerProvider.notifier);
  return um.getUserById(uid);
});

final userDisplayProvider = FutureProvider.autoDispose.family<String, String>((
  ref,
  uid,
) async {
  ref.watch(tenantIdProvider);
  if (uid.isEmpty) return '';

  AuthUser? user;
  try {
    user = await ref.read(authUserByIdProvider(uid).future);
  } catch (_) {
    user = null;
  }
  if (user != null) return user.displayLabel();

  final me = fb.FirebaseAuth.instance.currentUser;
  if (me?.uid == uid) {
    return resolveUserDisplay(
      displayName: me?.displayName,
      email: me?.email,
      phone: me?.phoneNumber,
      uid: uid,
    );
  }
  return uid;
});

final currentUserDisplayProvider = Provider.autoDispose<String?>((ref) {
  ref.watch(tenantIdProvider);
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || uid.isEmpty) return null;

  final meAsync = ref.watch(authUserByIdProvider(uid));
  return meAsync.maybeWhen(data: (u) => u!.displayLabel(), orElse: () => null);
});

final userDisplayNameProvider = Provider.autoDispose<String?>((ref) {
  final me = ref.watch(currentAuthUserProvider);
  return me.maybeWhen(data: (u) => u!.displayLabel(), orElse: () => null);
});
