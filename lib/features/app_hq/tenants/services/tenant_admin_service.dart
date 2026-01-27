import 'dart:async';
import 'dart:convert';

import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes.dart';
import 'package:afyakit/core/tenancy/extensions/tenant_status_x.dart';
import 'package:afyakit/core/tenancy/models/tenant_profile.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef Json = Map<String, dynamic>;

final tenantAdminServiceProvider =
    FutureProvider.autoDispose<TenantAdminService>((ref) async {
      final tenantSlug = ref.watch(tenantSlugProvider);
      final client = await ref.watch(afyakitClientProvider.future);
      final routes = AfyaKitRoutes(tenantSlug);
      return TenantAdminService(dio: client.dio, routes: routes);
    });

class TenantAdminService {
  TenantAdminService({required this.dio, required this.routes});

  final Dio dio;
  final AfyaKitRoutes routes;

  static const _json = Headers.jsonContentType;
  static const _tag = '[TenantProfileService]';

  // ─────────────────────────────────────────────
  // helpers
  // ─────────────────────────────────────────────

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
    final listish = m['results'] ?? m['items'] ?? m['tenants'] ?? m['data'];
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

  // ─────────────────────────────────────────────
  // list / get
  // ─────────────────────────────────────────────

  Future<List<TenantProfile>> listTenantProfiles() async {
    final r = await dio.getUri(routes.listTenants());
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'List tenants');

    final list = _asList(r.data).mapIndexed((i, m) {
      final slug = (m['slug'] ?? m['id'] ?? '').toString();
      return TenantProfile.fromFirestore(slug, m);
    }).toList();

    if (kDebugMode) {
      debugPrint('✅ $_tag Loaded ${list.length} tenant profiles');
    }
    return list;
  }

  Stream<List<TenantProfile>> streamTenantProfiles({
    Duration every = const Duration(seconds: 8),
  }) async* {
    yield await listTenantProfiles();
    yield* Stream.periodic(every).asyncMap((_) => listTenantProfiles());
  }

  Future<TenantProfile> getTenantProfile(String slug) async {
    final r = await dio.getUri(routes.getTenant(slug));
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Get tenant profile');
    final m = _asMap(r.data);
    return TenantProfile.fromFirestore(slug, m);
  }

  // ─────────────────────────────────────────────
  // create / update
  // ─────────────────────────────────────────────

  Future<String> createTenantProfile({
    required String displayName,
    String? slug,
    String primaryColorHex = '#1565C0',
    Map<String, bool> features = const {},
    Json assets = const {},
    Json profile = const {},
    TenantStatus status = TenantStatus.active,
  }) async {
    final payload = <String, dynamic>{
      'displayName': displayName,
      if (slug != null && slug.trim().isNotEmpty) 'slug': _slugify(slug),
      'primaryColorHex': primaryColorHex,
      if (features.isNotEmpty) 'features': features,
      if (assets.isNotEmpty) 'assets': assets,
      if (profile.isNotEmpty) 'profile': profile,
      'status': status.value,
    };

    final r = await dio.postUri(
      routes.createTenant(),
      data: payload,
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Create tenant profile');

    final m = _asMap(r.data);
    final createdSlug = (m['slug'] ?? payload['slug'] ?? '').toString();
    if (kDebugMode) {
      debugPrint('✅ $_tag TenantProfile created: $createdSlug');
    }
    return createdSlug;
  }

  Future<void> updateTenantProfile({
    required String slug,
    String? displayName,
    String? primaryColorHex,
    Map<String, bool>? features,
    Json? assets,
    Json? profile,
    TenantStatus? status,
  }) async {
    final payload = <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (primaryColorHex != null) 'primaryColorHex': primaryColorHex,
      if (features != null) 'features': features,
      if (assets != null) 'assets': assets,
      if (profile != null) 'profile': profile,
      if (status != null) 'status': status.value,
    };
    if (payload.isEmpty) return;

    final r = await dio.patchUri(
      routes.updateTenant(slug),
      data: payload,
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Update tenant profile');

    if (kDebugMode) {
      debugPrint('✅ $_tag TenantProfile $slug updated: $payload');
    }
  }

  Future<void> deleteTenantProfile(String slug, {bool hard = false}) async {
    final uri = hard
        ? routes.deleteTenant(slug).replace(queryParameters: {'hard': '1'})
        : routes.deleteTenant(slug);

    final r = await dio.deleteUri(uri);
    final ok = (r.statusCode == 204) || ((r.statusCode ?? 0) ~/ 100 == 2);
    if (!ok) _bad(r, 'Delete tenant profile');

    if (kDebugMode) {
      debugPrint('🗑️ $_tag TenantProfile deleted: $slug (hard=$hard)');
    }
  }

  // ─────────────────────────────────────────────
  // owner / status helpers
  // ─────────────────────────────────────────────

  Future<void> setStatus(String slug, TenantStatus status) async {
    final r = await dio.postUri(
      routes.setTenantStatus(slug),
      data: {'status': status.value},
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Set tenant status');
  }

  Future<void> setOwnerByEmail({
    required String slug,
    required String email,
  }) async {
    final target = email.trim();
    if (target.isEmpty) {
      throw ArgumentError.value(email, 'email', 'must not be empty');
    }
    await _transferOwner(slug: slug, payload: {'email': target});
  }

  Future<void> setOwnerByUid({
    required String slug,
    required String uid,
  }) async {
    final target = uid.trim();
    if (target.isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'must not be empty');
    }
    await _transferOwner(slug: slug, payload: {'uid': target});
  }

  Future<void> _transferOwner({
    required String slug,
    required Map<String, dynamic> payload,
  }) async {
    final r = await dio.postUri(
      routes.setTenantOwner(slug),
      data: payload,
      options: Options(
        contentType: Headers.jsonContentType,
        validateStatus: (s) => s != null && s < 500,
        receiveDataWhenStatusError: true,
      ),
    );

    if (kDebugMode) {
      debugPrint('🛰️ $_tag setOwner → ${r.statusCode}');
      debugPrint('🛰️ $_tag body: ${r.data}');
    }

    if (r.statusCode != 200 && r.statusCode != 204) {
      final body = _asMap(r.data);
      final code = (body['error'] ?? 'error').toString();
      final msg = (body['message'] ?? 'Request failed').toString();
      throw Exception('$code: $msg');
    }
  }

  // ─────────────────────────────────────────────
  // utils
  // ─────────────────────────────────────────────

  String _slugify(String input) {
    final s = input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return s.isNotEmpty ? s : 'tenant';
  }
}
