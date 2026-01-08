// lib/core/tenancy/providers/tenant_session_guard_provider.dart
// (FULL FILE with minimal edits)

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

String _normTenant(String s) => s.trim().toLowerCase();
bool _is2xx(int? s) => s != null && s >= 200 && s < 300;

/// De-dupe per UID (claims are per-user; session checks are per-user-per-tenant).
final Map<String, Future<void>> _inflightByKey = <String, Future<void>>{};

@immutable
class TenantSessionCheckResult {
  final int statusCode;
  final Map<String, dynamic>? body;

  const TenantSessionCheckResult({
    required this.statusCode,
    required this.body,
  });

  bool get ok => _is2xx(statusCode);

  String? get errorCode =>
      body == null ? null : body!['error']?.toString().trim();

  String? get message =>
      body == null ? null : body!['message']?.toString().trim();
}

Future<TenantSessionCheckResult> _checkSessionForTenant({
  required String tenantSlug,
  required fb.User fbUser,
}) async {
  final token = await fbUser.getIdToken();

  final dio = Dio(
    BaseOptions(
      baseUrl: _apiBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      validateStatus: (s) => s != null && s < 500,
      receiveDataWhenStatusError: true,
    ),
  );

  final resp = await dio.get(
    '/$tenantSlug/auth/session/me',
    options: Options(
      headers: <String, String>{
        if (token != null && token.trim().isNotEmpty)
          'Authorization': 'Bearer ${token.trim()}',
      },
    ),
  );

  Map<String, dynamic>? body;
  if (resp.data is Map) {
    body = Map<String, dynamic>.from(resp.data as Map);
  }

  return TenantSessionCheckResult(statusCode: resp.statusCode ?? 0, body: body);
}

final tenantSessionGuardProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final tenantSlug = _normTenant(ref.watch(tenantSlugProvider));

  final link = ref.keepAlive();
  Timer? purge;
  ref.onCancel(() => purge = Timer(const Duration(seconds: 20), link.close));
  ref.onResume(() => purge?.cancel());

  final fbUser = fb.FirebaseAuth.instance.currentUser;
  if (fbUser == null) {
    if (kDebugMode) debugPrint('⚠️ [tenant-guard] no Firebase user');
    return;
  }

  final uid = fbUser.uid;
  final key = '$uid@$tenantSlug';

  final inflight = _inflightByKey[key];
  if (inflight != null) {
    if (kDebugMode) debugPrint('⏳ [tenant-guard] reuse inflight key=$key');
    return inflight;
  }

  final future = () async {
    try {
      if (kDebugMode) {
        debugPrint(
          '🧭 [tenant-guard] check session tenant=$tenantSlug uid=$uid',
        );
      }

      final r = await _checkSessionForTenant(
        tenantSlug: tenantSlug,
        fbUser: fbUser,
      );

      if (kDebugMode) {
        debugPrint(
          '🧾 [tenant-guard] /auth/session/me http=${r.statusCode} '
          'error=${r.errorCode ?? '-'} msg=${r.message ?? '-'}',
        );
      }

      if (r.ok) {
        if (kDebugMode)
          debugPrint('✅ [tenant-guard] OK tenant=$tenantSlug uid=$uid');
        return;
      }

      // ✅ If session is invalid for this tenant, force guest.
      // Do NOT throw: throwing bricks providers that await this (and creates trap states).
      if (kDebugMode) {
        debugPrint(
          '🚪 [tenant-guard] invalid session; signing out uid=$uid tenant=$tenantSlug',
        );
      }

      await fb.FirebaseAuth.instance.signOut();
      return;
    } finally {
      _inflightByKey.remove(key);
    }
  }();

  _inflightByKey[key] = future;
  return future;
});
