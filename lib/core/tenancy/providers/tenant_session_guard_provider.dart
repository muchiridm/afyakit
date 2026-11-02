import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

const _apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://api.afyakit.app/api',
);

String _normId(String value) => value.trim().toLowerCase();

bool _is2xx(int? status) => status != null && status >= 200 && status < 300;

/// Deduplicate checks by Firebase user, tenant and application.
final Map<String, Future<void>> _inflightByKey = <String, Future<void>>{};

@immutable
class TenantSessionCheckResult {
  const TenantSessionCheckResult({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final Map<String, dynamic>? body;

  bool get ok => _is2xx(statusCode);

  String? get errorCode => body?['error']?.toString().trim();

  String? get message => body?['message']?.toString().trim();
}

Future<TenantSessionCheckResult> _checkSessionForTenant({
  required String tenantId,
  required String appId,
  required fb.User fbUser,
}) async {
  final token = await fbUser.getIdToken();

  if (token == null || token.trim().isEmpty) {
    throw StateError('Firebase authentication token unavailable');
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: _apiBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      validateStatus: (status) => status != null && status < 500,
      receiveDataWhenStatusError: true,
    ),
  );

  try {
    final response = await dio.get(
      '/$tenantId/auth/session/me',
      options: Options(
        headers: <String, String>{
          'Authorization': 'Bearer ${token.trim()}',
          'x-app-id': appId,
        },
      ),
    );

    Map<String, dynamic>? body;

    if (response.data is Map) {
      body = Map<String, dynamic>.from(response.data as Map);
    }

    return TenantSessionCheckResult(
      statusCode: response.statusCode ?? 0,
      body: body,
    );
  } finally {
    dio.close();
  }
}

final tenantSessionGuardProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final tenantId = _normId(ref.watch(tenantIdProvider));
  final appId = _normId(ref.watch(appIdProvider));

  final link = ref.keepAlive();
  Timer? purge;

  ref.onCancel(() {
    purge?.cancel();
    purge = Timer(const Duration(seconds: 20), link.close);
  });

  ref.onResume(() {
    purge?.cancel();
    purge = null;
  });

  ref.onDispose(() {
    purge?.cancel();
  });

  if (tenantId.isEmpty || appId.isEmpty) {
    throw StateError(
      'Tenant and application context must be initialized '
      'before checking the session.',
    );
  }

  final fbUser = fb.FirebaseAuth.instance.currentUser;

  if (fbUser == null) {
    if (kDebugMode) {
      debugPrint('⚠️ [tenant-guard] no Firebase user');
    }
    return;
  }

  final uid = fbUser.uid;
  final key = '$uid@$tenantId/$appId';

  final inflight = _inflightByKey[key];

  if (inflight != null) {
    if (kDebugMode) {
      debugPrint('⏳ [tenant-guard] reuse inflight key=$key');
    }
    return inflight;
  }

  final future = () async {
    try {
      if (kDebugMode) {
        debugPrint(
          '🧭 [tenant-guard] checking session '
          'tenant=$tenantId app=$appId uid=$uid',
        );
      }

      final result = await _checkSessionForTenant(
        tenantId: tenantId,
        appId: appId,
        fbUser: fbUser,
      );

      if (kDebugMode) {
        debugPrint(
          '🧾 [tenant-guard] /auth/session/me '
          'http=${result.statusCode} '
          'app=$appId '
          'error=${result.errorCode ?? '-'} '
          'message=${result.message ?? '-'}',
        );
      }

      if (result.ok) {
        if (kDebugMode) {
          debugPrint(
            '✅ [tenant-guard] session valid '
            'tenant=$tenantId app=$appId uid=$uid',
          );
        }
        return;
      }

      // Only an explicit authentication failure should clear
      // the Firebase login. Other failures must not silently
      // sign out an otherwise authenticated user.
      if (result.statusCode == 401) {
        if (kDebugMode) {
          debugPrint(
            '🚪 [tenant-guard] authentication rejected '
            'tenant=$tenantId app=$appId uid=$uid',
          );
        }

        // A previous request may finish after a new user signs in.
        // Never sign out a different Firebase user.
        if (fb.FirebaseAuth.instance.currentUser?.uid == uid) {
          await fb.FirebaseAuth.instance.signOut();
        }
        return;
      }

      // Fail closed for authorization or invalid application
      // context without destroying the Firebase session.
      throw StateError(
        'Session check failed: HTTP ${result.statusCode}'
        '${result.errorCode == null ? '' : ' · ${result.errorCode}'}',
      );
    } finally {
      _inflightByKey.remove(key);
    }
  }();

  _inflightByKey[key] = future;
  return future;
});
