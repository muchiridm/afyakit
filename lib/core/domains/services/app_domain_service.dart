// lib/core/domains/services/app_domain_service.dart

import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/domains/models/domain_binding.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/shared/utils/utils.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appDomainServiceProvider = FutureProvider.autoDispose<AppDomainService>((
  ref,
) async {
  // AfyaKitRoutes currently requires a tenantId to construct its base routes.
  //
  // App-domain HQ methods themselves receive the target tenantId/appId
  // explicitly, so this value is NOT the domain ownership scope.
  final currentTenantId = ref.watch(tenantIdProvider);

  final client = await ref.watch(afyakitClientFutureProvider.future);

  return AppDomainService(
    dio: client.dio,
    routes: AfyaKitRoutes(currentTenantId),
  );
});

class AppDomainService {
  AppDomainService({required this.dio, required this.routes});

  final Dio dio;
  final AfyaKitRoutes routes;

  static const String _json = Headers.jsonContentType;

  static const String _tag = '[AppDomainService]';

  // Accept 4xx so special cases such as 409 can be interpreted here.
  static bool _okOrClientError(int? status) {
    return status != null && status < 500;
  }

  bool _is2xx(int? status) {
    return status != null && status >= 200 && status < 300;
  }

  // ─────────────────────────────────────────────
  // Parsing
  // ─────────────────────────────────────────────

  List<JsonObj> _extractList(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);

      final listish = map['results'] ?? map['items'] ?? map['data'];

      if (listish is List) {
        return listish
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }

    return const <JsonObj>[];
  }

  JsonObj _extractMap(Object? raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return <String, dynamic>{};
  }

  Never _bad(Response<dynamic> response, String operation) {
    final data = response.data;

    final reason = data is Map ? data['error'] ?? data['message'] : null;

    throw Exception(
      '❌ $operation failed '
      '(${response.statusCode}): '
      '${reason ?? 'Unknown'}',
    );
  }

  String _cleanId(String value) {
    return value.trim().toLowerCase();
  }

  String _cleanDomain(String value) {
    return value.trim().toLowerCase();
  }

  // ─────────────────────────────────────────────
  // List
  // ─────────────────────────────────────────────

  Future<List<DomainBinding>> listAppDomains(
    String tenantId,
    String appId,
  ) async {
    final cleanTenantId = _cleanId(tenantId);

    final cleanAppId = _cleanId(appId);

    final response = await dio.getUri(
      routes.listAppDomains(cleanTenantId, cleanAppId),
      options: Options(
        validateStatus: _okOrClientError,
        receiveDataWhenStatusError: true,
      ),
    );

    if (!_is2xx(response.statusCode)) {
      _bad(response, 'List app domains');
    }

    final items = _extractList(response.data);

    return items.map(DomainBinding.fromMap).toList();
  }

  // ─────────────────────────────────────────────
  // Add
  // ─────────────────────────────────────────────

  /// Adds a domain to an app.
  ///
  /// Returns the DNS verification token when created.
  ///
  /// A 409 `domain-exists` is treated as idempotent success.
  /// A domain owned by another app remains an error.
  Future<String> addAppDomain(
    String tenantId,
    String appId,
    String domain,
  ) async {
    final cleanTenantId = _cleanId(tenantId);

    final cleanAppId = _cleanId(appId);

    final cleanDomain = _cleanDomain(domain);

    final response = await dio.postUri(
      routes.addAppDomain(cleanTenantId, cleanAppId),
      data: <String, dynamic>{'domain': cleanDomain},
      options: Options(
        contentType: _json,
        validateStatus: _okOrClientError,
        receiveDataWhenStatusError: true,
      ),
    );

    if (_is2xx(response.statusCode)) {
      final map = _extractMap(response.data);

      return (map['dnsToken'] ?? '').toString();
    }

    if (response.statusCode == 409) {
      final map = _extractMap(response.data);

      final error = (map['error'] ?? '').toString();

      if (error == 'domain-exists') {
        if (kDebugMode) {
          debugPrint(
            'ℹ️ $_tag domain already exists: '
            '$cleanDomain '
            '(tenant=$cleanTenantId, app=$cleanAppId)',
          );
        }

        return '';
      }
    }

    _bad(response, 'Add app domain');
  }

  // ─────────────────────────────────────────────
  // Verify
  // ─────────────────────────────────────────────

  Future<void> verifyAppDomain(
    String tenantId,
    String appId,
    String domain,
  ) async {
    final cleanTenantId = _cleanId(tenantId);

    final cleanAppId = _cleanId(appId);

    final cleanDomain = _cleanDomain(domain);

    final response = await dio.postUri(
      routes.verifyAppDomain(cleanTenantId, cleanAppId, cleanDomain),
      options: Options(
        contentType: _json,
        validateStatus: _okOrClientError,
        receiveDataWhenStatusError: true,
      ),
    );

    if (!_is2xx(response.statusCode)) {
      _bad(response, 'Verify app domain');
    }
  }

  // ─────────────────────────────────────────────
  // Primary
  // ─────────────────────────────────────────────

  Future<void> setPrimaryAppDomain(
    String tenantId,
    String appId,
    String domain,
  ) async {
    final cleanTenantId = _cleanId(tenantId);

    final cleanAppId = _cleanId(appId);

    final cleanDomain = _cleanDomain(domain);

    final response = await dio.postUri(
      routes.makePrimaryAppDomain(cleanTenantId, cleanAppId, cleanDomain),
      options: Options(
        contentType: _json,
        validateStatus: _okOrClientError,
        receiveDataWhenStatusError: true,
      ),
    );

    if (!_is2xx(response.statusCode)) {
      _bad(response, 'Make primary app domain');
    }
  }

  // ─────────────────────────────────────────────
  // Active
  // ─────────────────────────────────────────────

  Future<void> setAppDomainActive(
    String tenantId,
    String appId,
    String domain,
    bool active,
  ) async {
    final cleanTenantId = _cleanId(tenantId);

    final cleanAppId = _cleanId(appId);

    final cleanDomain = _cleanDomain(domain);

    final response = await dio.patchUri(
      routes.updateAppDomain(cleanTenantId, cleanAppId, cleanDomain),
      data: <String, dynamic>{'active': active},
      options: Options(
        contentType: _json,
        validateStatus: _okOrClientError,
        receiveDataWhenStatusError: true,
      ),
    );

    if (!_is2xx(response.statusCode)) {
      _bad(response, 'Set app domain active');
    }

    if (kDebugMode) {
      debugPrint(
        '✅ $_tag setAppDomainActive '
        '$cleanDomain → $active '
        '(tenant=$cleanTenantId, app=$cleanAppId)',
      );
    }
  }

  // ─────────────────────────────────────────────
  // Remove
  // ─────────────────────────────────────────────

  Future<void> removeAppDomain(
    String tenantId,
    String appId,
    String domain,
  ) async {
    final cleanTenantId = _cleanId(tenantId);

    final cleanAppId = _cleanId(appId);

    final cleanDomain = _cleanDomain(domain);

    final response = await dio.deleteUri(
      routes.removeAppDomain(cleanTenantId, cleanAppId, cleanDomain),
      options: Options(
        validateStatus: _okOrClientError,
        receiveDataWhenStatusError: true,
      ),
    );

    if (!_is2xx(response.statusCode)) {
      _bad(response, 'Remove app domain');
    }

    if (kDebugMode) {
      debugPrint(
        '🗑️ $_tag removed '
        '$cleanDomain '
        '(tenant=$cleanTenantId, app=$cleanAppId)',
      );
    }
  }
}
