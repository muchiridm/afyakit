// lib/hq/tenants/services/tenant_domain_service.dart

import 'dart:convert';

import 'package:afyakit/api/afyakit/providers.dart';
import 'package:afyakit/api/afyakit/routes.dart';
import 'package:afyakit/hq/tenants/models/domain_binding.dart';
import 'package:afyakit/hq/tenants/providers/tenant_slug_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef Json = Map<String, dynamic>;

final tenantDomainServiceProvider =
    FutureProvider.autoDispose<TenantDomainService>((ref) async {
      final tenantSlug = ref.watch(tenantSlugProvider);
      final client = await ref.watch(afyakitClientProvider.future);
      final routes = AfyaKitRoutes(tenantSlug);
      return TenantDomainService(dio: client.dio, routes: routes);
    });

class TenantDomainService {
  TenantDomainService({required this.dio, required this.routes});

  final Dio dio;
  final AfyaKitRoutes routes;

  static const _json = Headers.jsonContentType;
  static const _tag = '[TenantDomainService]';

  Json _asMap(Object? raw) {
    if (raw is Json) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(raw)));
  }

  List<Json> _asList(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    final m = _asMap(raw);
    final listish = m['results'] ?? m['items'] ?? m['data'];
    if (listish is List) {
      return listish
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  Never _bad(Response r, String op) {
    final reason = r.data is Map ? (r.data as Map)['error'] : null;
    throw Exception('❌ $op failed (${r.statusCode}): ${reason ?? 'Unknown'}');
  }

  Future<List<DomainBinding>> listTenantDomains(String slug) async {
    final r = await dio.getUri(routes.listDomains(slug));
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'List domains');
    return _asList(r.data).map((m) => DomainBinding.fromMap(m)).toList();
  }

  Future<String> addTenantDomain(String slug, String domain) async {
    final r = await dio.postUri(
      routes.addDomain(slug),
      data: {'domain': domain.trim()},
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Add domain');
    return _asMap(r.data)['dnsToken']?.toString() ?? '';
  }

  Future<void> verifyTenantDomain(String slug, String domain) async {
    final r = await dio.postUri(
      routes.verifyDomain(slug, domain),
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Verify domain');
  }

  Future<void> setPrimaryTenantDomain(String slug, String domain) async {
    final r = await dio.postUri(
      routes.makePrimaryDomain(slug, domain),
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Make primary domain');
  }

  Future<void> removeTenantDomain(String slug, String domain) async {
    final r = await dio.deleteUri(routes.removeDomain(slug, domain));
    final ok = (r.statusCode == 204) || ((r.statusCode ?? 0) ~/ 100 == 2);
    if (!ok) _bad(r, 'Remove domain');

    if (kDebugMode) {
      debugPrint('🗑️ $_tag removed domain $domain from $slug');
    }
  }
}
