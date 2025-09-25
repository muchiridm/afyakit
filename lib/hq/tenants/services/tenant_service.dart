// lib/tenants/services/tenant_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:afyakit/api/api_client.dart';
import 'package:afyakit/api/api_routes.dart';
import 'package:afyakit/hq/tenants/extensions/tenant_status_x.dart';
import 'package:afyakit/hq/tenants/models/domain_binding.dart';
import 'package:afyakit/hq/tenants/models/tenant_model.dart';
import 'package:afyakit/hq/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/core/auth_users/providers/auth_session/token_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tenantServiceProvider = FutureProvider.autoDispose<TenantService>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  final tokenProv = ref.read(tokenProvider);

  final client = await ApiClient.create(
    tenantId: tenantId,
    tokenProvider: tokenProv,
    withAuth: true,
  );
  final routes = ApiRoutes(tenantId);
  return TenantService(client: client, routes: routes);
});

/// TenantService → strictly tenant CRUD (+ status & flags).
class TenantService {
  TenantService({required this.client, required this.routes});

  final ApiClient client;
  final ApiRoutes routes;

  Dio get _dio => client.dio;
  static const _json = Headers.jsonContentType;
  static const _tag = '[TenantService]';

  // ── helpers ─────────────────────────────────────────────────
  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(raw)));
  }

  List<Map<String, dynamic>> _asList(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    final m = _asMap(raw);
    final results = m['results'];
    if (results is List) {
      return results
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

  // ─────────────────────────────────────────────────────────────
  // Utils
  // ─────────────────────────────────────────────────────────────

  /// Lowercase, strip non [a-z0-9 -], collapse spaces to '-', collapse dashes.
  String slugify(String input) {
    final s = input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return s.isNotEmpty ? s : 'tenant';
  }

  // ─────────────────────────────────────────────────────────────
  // Tenants – list / get / create / update / status / flags
  // ─────────────────────────────────────────────────────────────

  Future<List<Tenant>> listTenants() async {
    final r = await _dio.getUri(routes.listTenants());
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'List tenants');
    final list = _asList(r.data).map(Tenant.fromJson).toList();
    if (kDebugMode) debugPrint('✅ $_tag Loaded ${list.length} tenants');
    return list;
  }

  /// Lightweight polling stream to mimic snapshots.
  Stream<List<Tenant>> streamTenants({
    Duration every = const Duration(seconds: 8),
  }) async* {
    yield await listTenants();
    yield* Stream.periodic(every).asyncMap((_) => listTenants());
  }

  Future<Tenant> getTenant(String slug) async {
    final r = await _dio.getUri(routes.getTenant(slug));
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Get tenant');
    return Tenant.fromJson(_asMap(r.data));
  }

  /// Returns the slug created by the server.
  Future<String> createTenant({
    required String displayName,
    String? slug,
    String primaryColor = '#1565C0',
    String? logoPath,
    Map<String, dynamic> flags = const {},
  }) async {
    final payload = <String, dynamic>{
      'displayName': displayName,
      if (slug != null && slug.trim().isNotEmpty) 'slug': slugify(slug),
      'primaryColor': primaryColor,
      if (logoPath != null && logoPath.isNotEmpty) 'logoPath': logoPath,
      'flags': flags,
    };

    final r = await _dio.postUri(
      routes.createTenant(),
      data: payload,
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Create tenant');

    final m = _asMap(r.data);
    final createdSlug = (m['slug'] ?? payload['slug'] ?? '').toString();
    if (kDebugMode) debugPrint('✅ $_tag Tenant created: $createdSlug');
    return createdSlug;
  }

  Future<void> updateTenant({
    required String slug,
    String? displayName,
    String? primaryColor,
    String? logoPath,
    Map<String, dynamic>? flags, // full replace (server merge OK)
  }) async {
    final payload = <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (primaryColor != null) 'primaryColor': primaryColor,
      if (logoPath != null) 'logoPath': logoPath,
      if (flags != null) 'flags': flags,
    };
    if (payload.isEmpty) return;

    final r = await _dio.patchUri(
      routes.updateTenant(slug),
      data: payload,
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Update tenant');
    if (kDebugMode) debugPrint('✅ $_tag Tenant $slug updated: $payload');
  }

  Future<void> setStatusBySlug(String slug, TenantStatus status) async {
    // ← enum
    final r = await _dio.postUri(
      routes.setTenantStatus(slug),
      data: {'status': status.value}, // ← wire string
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Set tenant status');
    if (kDebugMode) debugPrint('✅ $_tag Tenant $slug → ${status.value}');
  }

  Future<void> setFlag(String slug, String key, Object? value) async {
    final r = await _dio.patchUri(
      routes.setTenantFlag(slug, key),
      data: {'value': value},
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Set tenant flag');
    if (kDebugMode) debugPrint('✅ $_tag Tenant $slug flag[$key]=$value');
  }

  /// Delete a tenant.
  /// If your backend supports soft vs hard delete via query (?hard=1),
  /// flip [hard] to true. Otherwise it just calls DELETE.
  Future<void> deleteTenant(String slug, {bool hard = false}) async {
    final uri = hard
        ? routes.deleteTenant(slug).replace(queryParameters: {'hard': '1'})
        : routes.deleteTenant(slug);

    final r = await _dio.deleteUri(uri);
    final ok = (r.statusCode == 204) || ((r.statusCode ?? 0) ~/ 100 == 2);
    if (!ok) _bad(r, 'Delete tenant');
    if (kDebugMode) debugPrint('🗑️ $_tag Tenant deleted: $slug (hard=$hard)');
  }

  /// Transfer tenant owner by email.
  /// Backend should resolve email -> uid and atomically set owner fields.
  Future<void> setOwnerByEmail({
    required String slug,
    required String email,
  }) async {
    final target = email.trim();
    if (target.isEmpty) {
      throw ArgumentError.value(email, 'email', 'must not be empty');
    }
    await _transferOwner(slug: slug, email: target);
  }

  /// Transfer tenant owner by uid.
  /// Backend should resolve uid -> email if stored.
  Future<void> setOwnerByUid({
    required String slug,
    required String uid,
  }) async {
    final target = uid.trim();
    if (target.isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'must not be empty');
    }
    await _transferOwner(slug: slug, uid: target);
  }

  /// Internal helper — calls a single endpoint that accepts either {email} or {uid}.
  Future<void> _transferOwner({
    required String slug,
    String? email,
    String? uid,
  }) async {
    assert(
      (email != null && uid == null) || (email == null && uid != null),
      'Provide exactly one of email or uid',
    );

    final payload = <String, dynamic>{
      if (email != null) 'email': email.trim(),
      if (uid != null) 'uid': uid.trim(),
    };

    if (kDebugMode) {
      debugPrint('🛰️ [TenantService] POST ${routes.setTenantOwner(slug)}');
      debugPrint('🛰️ [TenantService] payload=$payload');
    }

    final r = await _dio.postUri(
      routes.setTenantOwner(slug),
      data: payload,
      options: Options(
        contentType: Headers.jsonContentType,
        // 👇 accept all <500 so we can read the JSON body on 4xx
        validateStatus: (s) => s != null && s < 500,
        receiveDataWhenStatusError: true,
      ),
    );

    if (kDebugMode) {
      debugPrint(
        '🛰️ [TenantService] ← ${r.statusCode} type=${r.data.runtimeType}',
      );
      debugPrint('🛰️ [TenantService] body: ${r.data}');
    }

    // Success
    if (r.statusCode == 204 || r.statusCode == 200) {
      final who = email ?? uid!;
      if (kDebugMode) debugPrint('✅ [TenantService] Owner of $slug → $who');
      return;
    }

    // 4xx: show server error clearly
    final body = _asMap(r.data);
    final code = (body['error'] ?? 'error').toString();
    final msg = (body['message'] ?? 'Request failed').toString();
    throw Exception('$code: $msg'); // caught by your controller & toasted
  }

  Future<List<DomainBinding>> listTenantDomains(String slug) async {
    final r = await _dio.getUri(routes.listDomains(slug));
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'List domains');
    final list = _asList(r.data).map((m) => DomainBinding.fromMap(m)).toList();
    return list;
  }

  Future<String> addTenantDomain(String slug, String domain) async {
    final r = await _dio.postUri(
      routes.addDomain(slug),
      data: {'domain': domain.trim()},
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Add domain');
    // server returns DNS challenge details; surface token for UI
    return _asMap(r.data)['dnsToken']?.toString() ?? '';
  }

  Future<void> verifyTenantDomain(String slug, String domain) async {
    final r = await _dio.postUri(
      routes.verifyDomain(slug, domain),
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Verify domain');
  }

  Future<void> setPrimaryTenantDomain(String slug, String domain) async {
    final r = await _dio.postUri(
      routes.makePrimaryDomain(slug, domain),
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Make primary domain');
  }

  Future<void> removeTenantDomain(String slug, String domain) async {
    final r = await _dio.deleteUri(routes.removeDomain(slug, domain));
    final ok = (r.statusCode == 204) || ((r.statusCode ?? 0) ~/ 100 == 2);
    if (!ok) _bad(r, 'Remove domain');
  }

  // TenantService

  /// Remove owner by uid. By default we DEMOTE (safer). Pass `hard=true` to remove membership.
  Future<void> removeOwnerByUid({
    required String slug,
    required String uid,
    bool hard = false, // false = demote to admin, true = remove membership
  }) async {
    final uri = routes
        .removeTenantOwner(slug)
        .replace(
          queryParameters: {
            'uid': uid.trim(),
            if (hard) 'mode': 'remove', // default is 'demote'
          },
        );

    final r = await _dio.deleteUri(uri);
    final ok = (r.statusCode == 204) || ((r.statusCode ?? 0) ~/ 100 == 2);
    if (!ok) _bad(r, 'Remove owner by uid');
    if (kDebugMode) {
      debugPrint(
        '🗑️ [TenantService] Owner removed (mode=${hard ? 'remove' : 'demote'}) tenant=$slug uid=$uid',
      );
    }
  }

  /// Remove owner by email (server resolves email→uid).
  Future<void> removeOwnerByEmail({
    required String slug,
    required String email,
    bool hard = false,
  }) async {
    final target = email.trim().toLowerCase();
    if (target.isEmpty) {
      throw ArgumentError.value(email, 'email', 'must not be empty');
    }

    final uri = routes
        .removeTenantOwner(slug)
        .replace(
          queryParameters: {'email': target, if (hard) 'mode': 'remove'},
        );

    final r = await _dio.deleteUri(uri);
    final ok = (r.statusCode == 204) || ((r.statusCode ?? 0) ~/ 100 == 2);
    if (!ok) _bad(r, 'Remove owner by email');
    if (kDebugMode) {
      debugPrint(
        '🗑️ [TenantService] Owner removed (mode=${hard ? 'remove' : 'demote'}) tenant=$slug email=$target',
      );
    }
  }
}
