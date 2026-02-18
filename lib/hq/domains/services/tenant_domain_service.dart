// lib/hq/domains/services/tenant_domain_service.dart

import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/hq/domains/models/domain_binding.dart';
import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef Json = Map<String, dynamic>;

final tenantDomainServiceProvider =
    FutureProvider.autoDispose<TenantDomainService>((ref) async {
      final tenantSlug = ref.watch(tenantSlugProvider);
      final client = await ref.watch(afyakitClientFutureProvider.future);
      final routes = AfyaKitRoutes(tenantSlug);
      return TenantDomainService(dio: client.dio, routes: routes);
    });

class TenantDomainService {
  TenantDomainService({required this.dio, required this.routes});

  final Dio dio;
  final AfyaKitRoutes routes;

  static const _json = Headers.jsonContentType;
  static const _tag = '[TenantDomainService]';

  // Accept 4xx so we can handle 409 idempotently without Dio throwing.
  static bool _okOrClientError(int? s) => s != null && s < 500;

  // ─────────────────────────────────────────────
  // parsing helpers
  // ─────────────────────────────────────────────

  List<Json> _extractList(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      final listish = m['results'] ?? m['items'] ?? m['data'];
      if (listish is List) {
        return listish
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return const <Json>[];
  }

  Json _extractMap(Object? raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  Never _bad(Response<dynamic> r, String op) {
    final data = r.data;
    final reason = data is Map ? (data['error'] ?? data['message']) : null;
    throw Exception('❌ $op failed (${r.statusCode}): ${reason ?? 'Unknown'}');
  }

  bool _is2xx(int? s) => s != null && s >= 200 && s < 300;

  // ─────────────────────────────────────────────
  // API
  // ─────────────────────────────────────────────

  Future<List<DomainBinding>> listTenantDomains(String slug) async {
    final r = await dio.getUri(
      routes.listDomains(slug),
      options: Options(
        validateStatus: _okOrClientError,
        receiveDataWhenStatusError: true,
      ),
    );
    if (!_is2xx(r.statusCode)) _bad(r, 'List domains');

    final items = _extractList(r.data);
    return items.map(DomainBinding.fromMap).toList();
  }

  /// Add a domain to a tenant allowlist.
  ///
  /// Returns dnsToken when CREATED.
  /// If already exists (409 domain-exists), returns '' (idempotent).
  Future<String> addTenantDomain(String slug, String domain) async {
    final r = await dio.postUri(
      routes.addDomain(slug),
      data: <String, dynamic>{'domain': domain.trim()},
      options: Options(
        contentType: _json,
        validateStatus: _okOrClientError,
        receiveDataWhenStatusError: true,
      ),
    );

    // ✅ Created
    if (r.statusCode == 201 || r.statusCode == 200) {
      final m = _extractMap(r.data);
      return (m['dnsToken'] ?? '').toString();
    }

    // ✅ Already exists (treat as success)
    if (r.statusCode == 409) {
      final m = _extractMap(r.data);
      final err = (m['error'] ?? '').toString();
      if (err == 'domain-exists') {
        if (kDebugMode) {
          debugPrint('ℹ️ $_tag add domain: already exists ($domain) for $slug');
        }
        return '';
      }
    }

    _bad(r, 'Add domain');
  }

  Future<void> verifyTenantDomain(String slug, String domain) async {
    final r = await dio.postUri(
      routes.verifyDomain(slug, domain),
      options: Options(
        contentType: _json,
        validateStatus: _okOrClientError,
        receiveDataWhenStatusError: true,
      ),
    );

    final ok = (r.statusCode == 204) || _is2xx(r.statusCode);
    if (!ok) _bad(r, 'Verify domain');
  }

  Future<void> setPrimaryTenantDomain(String slug, String domain) async {
    final r = await dio.postUri(
      routes.makePrimaryDomain(slug, domain),
      options: Options(
        contentType: _json,
        validateStatus: _okOrClientError,
        receiveDataWhenStatusError: true,
      ),
    );

    final ok = (r.statusCode == 204) || _is2xx(r.statusCode);
    if (!ok) _bad(r, 'Make primary domain');
  }

  Future<void> removeTenantDomain(String slug, String domain) async {
    final r = await dio.deleteUri(
      routes.removeDomain(slug, domain),
      options: Options(
        validateStatus: _okOrClientError,
        receiveDataWhenStatusError: true,
      ),
    );

    final ok = (r.statusCode == 204) || _is2xx(r.statusCode);
    if (!ok) _bad(r, 'Remove domain');

    if (kDebugMode) {
      debugPrint('🗑️ $_tag removed domain $domain from $slug');
    }
  }

  /// Toggle allowlist active flag:
  /// PATCH /tenants/:slug/domains/:domain { active: true/false }
  Future<void> setTenantDomainActive(
    String slug,
    String domain,
    bool active,
  ) async {
    final r = await dio.patchUri(
      routes.updateDomain(slug, domain),
      data: <String, dynamic>{'active': active},
      options: Options(
        contentType: _json,
        validateStatus: _okOrClientError,
        receiveDataWhenStatusError: true,
      ),
    );

    final ok = (r.statusCode == 204) || _is2xx(r.statusCode);
    if (!ok) _bad(r, 'Set domain active');

    if (kDebugMode) {
      debugPrint('✅ $_tag setDomainActive $domain → $active (tenant=$slug)');
    }
  }
}
