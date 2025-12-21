// lib/core/tenancy/providers/tenant_session_guard_provider.dart

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

const _apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://api.afyakit.app/api',
);

final tenantSessionGuardProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final tenantSlug = ref.watch(tenantSlugProvider);

  // keep alive briefly to avoid thrashing
  final link = ref.keepAlive();
  Timer? purge;
  ref.onCancel(() => purge = Timer(const Duration(seconds: 20), link.close));
  ref.onResume(() => purge?.cancel());

  final fbUser = fb.FirebaseAuth.instance.currentUser;
  if (fbUser == null) {
    if (kDebugMode) debugPrint('⚠️ [tenant-guard] no Firebase user');
    return;
  }

  // 1) Refresh token first
  await fbUser.getIdToken(true);

  // 2) Check claims
  final before = await fbUser.getIdTokenResult();
  final claims = before.claims ?? const <String, dynamic>{};
  final claimTenant = (claims['tenant'] ?? claims['tenantId'])?.toString();

  if (claimTenant == tenantSlug) {
    if (kDebugMode) {
      debugPrint('✅ [tenant-guard] claims already match ($tenantSlug)');
    }
    return;
  }

  if (kDebugMode) {
    debugPrint(
      '⚠️ [tenant-guard] claim mismatch: claimTenant=$claimTenant pathTenant=$tenantSlug → syncing…',
    );
  }

  // 3) Call backend to sync claims
  final dio = Dio(BaseOptions(baseUrl: _apiBase));
  final idToken = await fbUser.getIdToken();

  final r = await dio.post(
    '/$tenantSlug/auth/session/sync-claims',
    options: Options(
      headers: {'Authorization': 'Bearer $idToken'},
      validateStatus: (s) => s != null && s < 500,
      receiveDataWhenStatusError: true,
    ),
  );

  if (r.statusCode != 200 && r.statusCode != 204) {
    if (kDebugMode) {
      debugPrint(
        '⚠️ [tenant-guard] sync-claims refused (status=${r.statusCode}) body=${r.data}',
      );
    }
    // Do not throw; just proceed with mismatch (app can still show login etc.)
    return;
  }

  // 4) Force refresh so new claims show up
  await fbUser.getIdToken(true);

  if (kDebugMode) {
    final after = await fbUser.getIdTokenResult();
    final newTenant = (after.claims?['tenant'] ?? after.claims?['tenantId'])
        ?.toString();
    debugPrint('✅ [tenant-guard] synced. new claimTenant=$newTenant');
  }
});
