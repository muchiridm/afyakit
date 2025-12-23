// lib/core/auth_user/providers/current_user_providers.dart

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes.dart';
import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

/// Keep a per-tenant inflight lock so multiple widgets don't spam /me.
final Map<String, Future<AuthUser>> _meInflightByTenant =
    <String, Future<AuthUser>>{};

String _normTenant(String s) => s.trim().toLowerCase();

/// Reactive Firebase user (null immediately on logout).
final firebaseUserProvider = StreamProvider<fb.User?>((ref) {
  return fb.FirebaseAuth.instance.authStateChanges();
});

/// Canonical current user for the selected tenant.
/// - Reacts instantly to logout (fb auth stream).
/// - Ensures we only hit /auth/session/me ONCE even if many widgets read it.
final currentUserProvider = FutureProvider.autoDispose<AuthUser?>((ref) async {
  // Keep alive briefly to avoid rebuild storms creating multiple fetches.
  final link = ref.keepAlive();
  Timer? purge;
  ref.onCancel(() => purge = Timer(const Duration(seconds: 20), link.close));
  ref.onResume(() => purge?.cancel());

  final tenantId = _normTenant(ref.watch(tenantSlugProvider));

  final fbUserAsync = ref.watch(firebaseUserProvider);
  final fbUser = fbUserAsync.valueOrNull;

  if (fbUser == null) {
    if (kDebugMode) debugPrint('👤 [currentUser] fbUser=null → return null');
    return null;
  }

  // IMPORTANT: afyakitClientProvider already awaits tenantSessionGuardProvider.future
  final client = await ref.watch(afyakitClientProvider.future);
  final baseUrl = client.dio.options.baseUrl;

  final key = '$tenantId@$baseUrl';

  final inflight = _meInflightByTenant[key];
  if (inflight != null) {
    if (kDebugMode) debugPrint('⏳ [currentUser] reuse inflight key=$key');
    return inflight;
  }

  final future = () async {
    try {
      final routes = AfyaKitRoutes(tenantId);
      final uri = routes.getCurrentUser();

      if (kDebugMode) {
        debugPrint(
          '🛰️ [currentUser] GET $uri (tenant=$tenantId uid=${fbUser.uid})',
        );
      }

      final r = await client.dio.getUri(uri);

      if (r.data is! Map) {
        throw StateError('Unexpected /me response type: ${r.data.runtimeType}');
      }

      final data = Map<String, dynamic>.from(r.data as Map);
      final me = AuthUser.fromJson(data);

      if (kDebugMode) {
        debugPrint(
          '✅ [currentUser] loaded uid=${me.uid} tenant=${me.tenantId} type=${me.type}',
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

/// Convenience: plain AuthUser? value (or null) without dealing with AsyncValue.
final currentUserValueProvider = Provider<AuthUser?>((ref) {
  final async = ref.watch(currentUserProvider);
  return async.valueOrNull;
});

/// Display-friendly label
final userDisplayNameProvider = Provider<String?>((ref) {
  final u = ref.watch(currentUserValueProvider);
  if (u == null) return null;

  final name = u.displayName.trim();
  if (name.isNotEmpty) return name;

  final phone = u.phoneNumber.trim();
  return phone.isNotEmpty ? phone : null;
});
