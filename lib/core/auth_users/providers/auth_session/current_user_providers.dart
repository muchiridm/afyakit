// lib/core/auth_users/providers/auth_session/current_user_providers.dart
import 'dart:async';
import 'package:afyakit/hq/tenants/providers/tenant_slug_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:dio/dio.dart' show DioException;

import 'package:afyakit/shared/utils/provider_utils.dart';
import 'package:afyakit/shared/utils/dev_trace.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_user_display.dart';

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

  // 1) Firebase user
  final fbUser = await _waitForFbUser(
    timeout: const Duration(seconds: 4),
    where: 'merged',
  );
  if (fbUser == null) {
    t.done('no-fbUser');
    if (verbose) pLog('🛡 [currentAuthUser] no fbUser (tenant=$tenantId)');
    return null;
  }

  // 2) API user document
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

  // 3) Claims
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

/// ─────────────────────────────────────────────────────────────
/// currentUser = session-backed (what AuthGate also sees)
/// ─────────────────────────────────────────────────────────────

final currentUserProvider = Provider<AsyncValue<AuthUser?>>((ref) {
  final tenantId = ref.watch(tenantSlugProvider);
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
  final tenantId = ref.read(tenantSlugProvider);
  final ctrl = ref.read(sessionControllerProvider(tenantId).notifier);
  await ctrl.ensureReady();
  return ctrl.currentUser;
});

/// ─────────────────────────────────────────────────────────────
/// currentAuthUser = merged (doc + claims) when allowed
/// ─────────────────────────────────────────────────────────────

final currentAuthUserProvider = FutureProvider<AuthUser?>((ref) async {
  final tenantId = ref.read(tenantSlugProvider);
  final t = DevTrace('currentAuthUser', context: {'tenant': tenantId});

  // 1) session first
  await ref.read(currentUserFutureProvider.future);
  t.log('session-hydrated');

  // 2) check session mode
  final sessionCtrl = ref.read(sessionControllerProvider(tenantId).notifier);
  final sessionUser = sessionCtrl.currentUser;
  final isLimited = sessionCtrl.isLimited;

  if (isLimited) {
    t.done('limited-session → using sessionUser only');
    return sessionUser;
  }

  // 3) relaxed merged fetch
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

  // 4) forced merged fetch
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

final authUserByIdProvider = FutureProvider.autoDispose
    .family<AuthUser?, String>((ref, uid) async {
      final tenantId = ref.watch(tenantSlugProvider);
      if (uid.isEmpty) return null;

      keepAliveFor(ref, const Duration(minutes: 5));

      final sessionCtrl = ref.read(
        sessionControllerProvider(tenantId).notifier,
      );
      if (sessionCtrl.isLimited) {
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
  ref.watch(tenantSlugProvider);
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
  ref.watch(tenantSlugProvider);
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || uid.isEmpty) return null;

  final meAsync = ref.watch(authUserByIdProvider(uid));
  return meAsync.maybeWhen(data: (u) => u!.displayLabel(), orElse: () => null);
});

final userDisplayNameProvider = Provider.autoDispose<String?>((ref) {
  final me = ref.watch(currentAuthUserProvider);
  return me.maybeWhen(data: (u) => u!.displayLabel(), orElse: () => null);
});
