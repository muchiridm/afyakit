// lib/api/afyakit/providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/hq/tenants/providers/tenant_slug_provider.dart';
import 'package:afyakit/api/afyakit/config.dart';
import 'package:afyakit/api/afyakit/client.dart';

final afyakitClientProvider = FutureProvider<AfyaKitClient>((ref) async {
  final tenantId = ref.watch(tenantSlugProvider);
  final base = apiBaseUrl(tenantId);
  return AfyaKitClient.create(
    baseUrl: base,
    getToken: () async =>
        await fb.FirebaseAuth.instance.currentUser?.getIdToken(),
  );
});
