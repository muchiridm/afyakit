// lib/core/auth/auth_user/providers/current_users_providers.dart

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

/// Keep a per-user, per-tenant, per-app inflight lock so multiple widgets
/// don't spam /auth/session/me.
///
/// Important:
/// A tenant may host several applications, and the same Firebase UID may
/// have different staff roles in each application.
final Map<String, Future<AuthUser>> _meInflightByTenant =
    <String, Future<AuthUser>>{};

String _normTenant(String s) => s.trim().toLowerCase();

String _normApp(String s) => s.trim().toLowerCase();

/// Reactive Firebase user (null immediately on logout).
final firebaseUserProvider = StreamProvider<fb.User?>((ref) {
  return fb.FirebaseAuth.instance.authStateChanges();
});

/// Canonical current user for the selected tenant and application.
///
/// - Reacts instantly to logout (Firebase Auth stream).
/// - Uses the existing tenant and application providers.
/// - Ensures concurrent widgets share the same /auth/session/me request.
/// - Resolves staff permissions for the active application only.
/// - Does not grant access through legacy tenant-wide staffRoles.
final currentUserProvider = FutureProvider.autoDispose<AuthUser?>((ref) async {
  // Keep alive briefly to avoid rebuild storms creating multiple fetches.
  final link = ref.keepAlive();

  Timer? purge;

  ref.onCancel(() => purge = Timer(const Duration(seconds: 20), link.close));

  ref.onResume(() => purge?.cancel());

  // Tenant and application are separate contexts.
  //
  // Example:
  //   tenantId = afya
  //   appId    = dawapap
  final tenantId = _normTenant(ref.watch(tenantIdProvider));

  final appId = _normApp(ref.watch(appIdProvider));

  final fbUserAsync = ref.watch(firebaseUserProvider);
  final fbUser = fbUserAsync.valueOrNull;

  if (fbUser == null) {
    if (kDebugMode) {
      debugPrint('👤 [currentUser] fbUser=null → return null');
    }

    return null;
  }

  // IMPORTANT:
  // afyakitClientFutureProvider already awaits
  // tenantSessionGuardProvider.future.
  final client = await ref.watch(afyakitClientFutureProvider.future);

  final baseUrl = client.dio.options.baseUrl;

  // Do not reuse an in-flight user response across identities,
  // tenants or applications.
  final key = '$tenantId@$appId@${fbUser.uid}@$baseUrl';

  final inflight = _meInflightByTenant[key];

  if (inflight != null) {
    if (kDebugMode) {
      debugPrint('⏳ [currentUser] reuse inflight key=$key');
    }

    return inflight;
  }

  final future = () async {
    try {
      final routes = AfyaKitRoutes(tenantId);
      final uri = routes.getCurrentUser();

      if (kDebugMode) {
        debugPrint(
          '🛰️ [currentUser] GET $uri '
          '(tenant=$tenantId '
          'app=$appId '
          'uid=${fbUser.uid})',
        );
      }

      final r = await client.dio.getUri(uri);

      if (r.data is! Map) {
        throw StateError(
          'Unexpected /me response type: '
          '${r.data.runtimeType}',
        );
      }

      final data = Map<String, dynamic>.from(r.data as Map);

      // Parse the canonical tenant account, then attach the
      // trusted application context.
      //
      // AuthUser.fromJson() does not accept activeAppId from JSON.
      //
      // AuthUser.forApp() resolves the existing staffRolesByApp
      // grants for the application currently running.
      final me = AuthUser.fromJson(data).forApp(appId);

      if (kDebugMode) {
        debugPrint(
          '✅ [currentUser] loaded '
          'uid=${me.uid} '
          'tenant=${me.tenantId} '
          'app=${me.activeAppId} '
          'roles=${me.staffRoles} '
          'staff=${me.isStaffResolved}',
        );
      }

      return me;
    } finally {
      _meInflightByTenant.remove(key);
    }
  }();

  _meInflightByTenant[key] = future;

  return future;
});

/// Convenience: plain AuthUser? value (or null)
/// without dealing with AsyncValue.
final currentUserValueProvider = Provider<AuthUser?>((ref) {
  final async = ref.watch(currentUserProvider);

  return async.valueOrNull;
});

/// Display-friendly label.
final userDisplayNameProvider = Provider<String?>((ref) {
  final u = ref.watch(currentUserValueProvider);

  if (u == null) return null;

  final dn = (u.displayName ?? '').trim();

  if (dn.isNotEmpty) return dn;

  final full = u.computedDisplayName.trim();

  return full.isNotEmpty ? full : null;
});
