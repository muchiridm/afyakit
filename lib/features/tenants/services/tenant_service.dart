// lib/tenants/services/tenant_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:afyakit/features/api/api_client.dart';
import 'package:afyakit/features/api/api_routes.dart';
import 'package:afyakit/features/tenants/models/tenant_dtos.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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

  Future<List<TenantSummary>> listTenants() async {
    final r = await _dio.getUri(routes.listTenants());
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'List tenants');
    final list = _asList(r.data).map(TenantSummary.fromJson).toList();
    if (kDebugMode) debugPrint('✅ $_tag Loaded ${list.length} tenants');
    return list;
  }

  /// Lightweight polling stream to mimic snapshots.
  Stream<List<TenantSummary>> streamTenants({
    Duration every = const Duration(seconds: 8),
  }) async* {
    yield await listTenants();
    yield* Stream.periodic(every).asyncMap((_) => listTenants());
  }

  Future<TenantSummary> getTenant(String slug) async {
    final r = await _dio.getUri(routes.getTenant(slug));
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Get tenant');
    return TenantSummary.fromJson(_asMap(r.data));
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

  Future<void> setStatusBySlug(String slug, String status) async {
    final r = await _dio.postUri(
      routes.setTenantStatus(slug),
      data: {'status': status},
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Set tenant status');
    if (kDebugMode) debugPrint('✅ $_tag Tenant $slug → status=$status');
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
}
