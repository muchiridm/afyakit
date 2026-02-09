// lib/core/api/afyakit/providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/core/api/afyakit/config.dart';
import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_session_guard_provider.dart';

/// Async init (real client creation)
/// Async init (real client creation)
final afyakitClientFutureProvider = FutureProvider<AfyaKitClient>((ref) async {
  final user = fb.FirebaseAuth.instance.currentUser;

  // ✅ Only enforce claim/tenant sync when logged in.
  if (user != null) {
    // Ensure claims match tenant BEFORE any protected API call
    await ref.watch(tenantSessionGuardProvider.future);

    // Prime a fresh token once after guard attempts sync/poll.
    try {
      await user.getIdToken(true);
    } catch (_) {
      // ignore
    }
  }

  final tenantId = ref.watch(tenantSlugProvider).trim().toLowerCase();
  final base = apiBaseUrl(tenantId);

  return AfyaKitClient.create(
    baseUrl: base,
    getToken: () async => fb.FirebaseAuth.instance.currentUser?.getIdToken(),
    getFreshToken: () async =>
        fb.FirebaseAuth.instance.currentUser?.getIdToken(true),
  );
});

/// Sync accessor (never crashes)
final afyakitClientProvider = Provider<AfyaKitClient?>((ref) {
  return ref
      .watch(afyakitClientFutureProvider)
      .maybeWhen(data: (c) => c, orElse: () => null);
});

/// Strict accessor (use only where you WANT to throw if not ready)
extension AfyaKitClientRefX on Ref {
  AfyaKitClient get afyakitClient {
    final c = read(afyakitClientProvider);
    if (c == null) throw StateError('AfyaKitClient not ready');
    return c;
  }
}
