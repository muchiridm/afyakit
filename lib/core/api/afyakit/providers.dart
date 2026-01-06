// lib/core/api/afyakit/providers.dart

import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_session_guard_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/core/api/afyakit/config.dart';
import 'package:afyakit/core/api/afyakit/client.dart';

final afyakitClientProvider = FutureProvider<AfyaKitClient>((ref) async {
  // Ensure claims match tenant BEFORE any protected API call
  await ref.watch(tenantSessionGuardProvider.future);

  // Prime a fresh token once after guard attempts sync/poll.
  // This helps in the common case where getIdToken() lags behind newly-minted claims.
  final user = fb.FirebaseAuth.instance.currentUser;
  if (user != null) {
    try {
      await user.getIdToken(true);
    } catch (_) {
      // Ignore: we'll still proceed; interceptor will handle missing token.
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
