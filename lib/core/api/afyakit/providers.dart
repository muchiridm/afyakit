// lib/api/afyakit/providers.dart

import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_session_guard_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/core/api/afyakit/config.dart';
import 'package:afyakit/core/api/afyakit/client.dart';

final afyakitClientProvider = FutureProvider<AfyaKitClient>((ref) async {
  // IMPORTANT: ensure claims match tenant BEFORE any protected API call
  await ref.watch(tenantSessionGuardProvider.future);

  final tenantId = ref.watch(tenantSlugProvider);
  final base = apiBaseUrl(tenantId);

  return AfyaKitClient.create(
    baseUrl: base,
    getToken: () async =>
        await fb.FirebaseAuth.instance.currentUser?.getIdToken(),
  );
});
