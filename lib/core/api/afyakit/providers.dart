// lib/core/api/afyakit/providers.dart

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/config.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_session_guard_provider.dart';

/// Tenant-scoped API routes helper.
final afyakitRoutesProvider = Provider<AfyaKitRoutes>((ref) {
  final tenantId = ref.watch(tenantIdProvider).trim().toLowerCase();
  return AfyaKitRoutes(tenantId);
});

/// Builds the shared AfyaKit API client.
///
/// Guest users are supported:
/// - no tenant-session guard is required
/// - token callbacks simply return null
///
/// Logged-in users are guarded so tenant claims are aligned before
/// protected API calls are made.
final afyakitClientFutureProvider = FutureProvider<AfyaKitClient>((ref) async {
  final fb.User? user = fb.FirebaseAuth.instance.currentUser;

  if (user != null) {
    await ref.watch(tenantSessionGuardProvider.future);

    try {
      await user.getIdToken(true);
    } catch (_) {
      // Intentionally ignored: API client can still be created and
      // downstream calls may retry or fail with proper handling.
    }
  }

  final String tenantId = ref.watch(tenantIdProvider).trim().toLowerCase();
  final String baseUrl = apiBaseUrl(tenantId);

  return AfyaKitClient.create(
    baseUrl: baseUrl,
    getToken: () async => fb.FirebaseAuth.instance.currentUser?.getIdToken(),
    getFreshToken: () async =>
        fb.FirebaseAuth.instance.currentUser?.getIdToken(true),
  );
});

/// Nullable synchronous accessor for convenience in UI/provider code.
final afyakitClientProvider = Provider<AfyaKitClient?>((ref) {
  return ref
      .watch(afyakitClientFutureProvider)
      .maybeWhen(data: (client) => client, orElse: () => null);
});

extension AfyaKitClientRefX on Ref {
  /// Strict synchronous accessor.
  ///
  /// Use only in places where the client must already be ready.
  AfyaKitClient get afyakitClient {
    final AfyaKitClient? client = read(afyakitClientProvider);
    if (client == null) {
      throw StateError('AfyaKitClient is not ready');
    }
    return client;
  }

  AfyaKitRoutes get afyakitRoutes {
    return read(afyakitRoutesProvider);
  }
}
