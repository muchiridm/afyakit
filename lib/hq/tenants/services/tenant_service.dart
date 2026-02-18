// lib/hq/tenants/services/tenant_service.dart

import 'dart:convert';

import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/hq/tenants/extensions/tenant_status_x.dart';
import 'package:afyakit/hq/tenants/models/tenant_profile.dart';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tenant_json.dart';

/// ✅ Stable HQ service instance.
/// - Uses a ready `Dio` from the AfyaKit client provider.
/// - No nullable Dio.
/// - No tenantSlug coupling (HQ is "core").
final tenantServiceProvider = FutureProvider<TenantService>((ref) async {
  final client = await ref.watch(afyakitClientFutureProvider.future);

  // HQ routes are core-scoped; any tenantSlug you pass here should not affect
  // the core endpoints used in this service (listTenants(), createTenant(), etc.).
  //
  // Using a harmless placeholder keeps AfyaKitRoutes happy without coupling
  // this provider to tenantSlugProvider rebuilds.
  const hqSlug = 'afyakit';

  return TenantService(dio: client.dio, routes: AfyaKitRoutes(hqSlug));
});

class TenantService {
  TenantService({
    required Dio dio,
    required this.routes,
    Duration listCacheTtl = const Duration(seconds: 15),
  }) : _dio = dio,
       _listCacheTtl = listCacheTtl;

  final Dio _dio;
  final AfyaKitRoutes routes;

  static const _json = Headers.jsonContentType;
  static const _tag = '[TenantService]';

  bool _is2xx(int? s) => s != null && s >= 200 && s < 300;

  Never _bad(Response r, String op) {
    final reason = r.data is Map ? (r.data as Map)['error'] : null;
    throw Exception('❌ $op failed (${r.statusCode}): ${reason ?? 'Unknown'}');
  }

  // ─────────────────────────────────────────────
  // Request de-dupe + small cache (prevents spam)
  // ─────────────────────────────────────────────

  Future<List<TenantProfile>>? _inflightList;
  List<TenantProfile>? _cachedList;
  DateTime? _cachedAt;

  Duration _listCacheTtl;

  /// Read-only TTL (prefer passing TTL in ctor).
  Duration get listCacheTtl => _listCacheTtl;

  /// Optional runtime control, if you really need it.
  /// Keeping it explicit avoids hidden mutability.
  void setListCacheTtl(Duration ttl) => _listCacheTtl = ttl;

  void invalidateCache() {
    _cachedList = null;
    _cachedAt = null;
  }

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

  // ─────────────────────────────────────────────
  // list / get
  // ─────────────────────────────────────────────

  /// ✅ Single-shot fetch.
  /// - De-dupes concurrent calls
  /// - Uses short TTL cache to protect rebuilds
  Future<List<TenantProfile>> fetchTenantProfiles({bool forceRefresh = false}) {
    final now = DateTime.now();

    if (!forceRefresh && _listCacheTtl > Duration.zero) {
      final cached = _cachedList;
      final at = _cachedAt;
      if (cached != null && at != null) {
        final age = now.difference(at);
        if (age <= _listCacheTtl) return Future.value(cached);
      }
    }

    final inflight = _inflightList;
    if (!forceRefresh && inflight != null) return inflight;

    final fut = _fetchTenantProfilesNetwork().whenComplete(() {
      _inflightList = null;
    });

    _inflightList = fut;
    return fut;
  }

  Future<List<TenantProfile>> _fetchTenantProfilesNetwork() async {
    final r = await _dio.getUri(routes.listTenants());
    if (!_is2xx(r.statusCode)) _bad(r, 'List tenants');

    final list = _asList(r.data).mapIndexed((i, m) {
      final slug = (m['slug'] ?? m['id'] ?? '').toString();
      return TenantProfile.fromFirestore(slug, m);
    }).toList();

    _cachedList = list;
    _cachedAt = DateTime.now();

    if (kDebugMode) {
      debugPrint('✅ $_tag Loaded ${list.length} tenant profiles');
    }
    return list;
  }

  /// Backwards-compatible alias.
  Future<List<TenantProfile>> listTenantProfiles() => fetchTenantProfiles();

  Future<TenantProfile> getTenantProfile(String slug) async {
    final r = await _dio.getUri(routes.getTenant(slug));
    if (!_is2xx(r.statusCode)) _bad(r, 'Get tenant profile');
    final m = _asMap(r.data);
    return TenantProfile.fromFirestore(slug, m);
  }

  // ─────────────────────────────────────────────
  // create / update / delete
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

    final r = await _dio.postUri(
      routes.createTenant(),
      data: payload,
      options: Options(contentType: _json),
    );
    if (!_is2xx(r.statusCode)) _bad(r, 'Create tenant profile');

    invalidateCache();

    final m = _asMap(r.data);
    final createdSlug = (m['slug'] ?? payload['slug'] ?? '').toString();
    if (kDebugMode) {
      debugPrint('✅ $_tag Tenant created: $createdSlug');
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

    final r = await _dio.patchUri(
      routes.updateTenant(slug),
      data: payload,
      options: Options(contentType: _json),
    );
    if (!_is2xx(r.statusCode)) _bad(r, 'Update tenant profile');

    invalidateCache();

    if (kDebugMode) {
      debugPrint('✅ $_tag Tenant $slug updated');
    }
  }

  Future<void> deleteTenantProfile(String slug, {bool hard = false}) async {
    final uri = hard
        ? routes.deleteTenant(slug).replace(queryParameters: {'hard': '1'})
        : routes.deleteTenant(slug);

    final r = await _dio.deleteUri(uri);
    final ok = (r.statusCode == 204) || _is2xx(r.statusCode);
    if (!ok) _bad(r, 'Delete tenant profile');

    invalidateCache();

    if (kDebugMode) {
      debugPrint('🗑️ $_tag Tenant deleted: $slug (hard=$hard)');
    }
  }

  // ─────────────────────────────────────────────
  // owner / status helpers
  // ─────────────────────────────────────────────

  Future<void> setStatus(String slug, TenantStatus status) async {
    final r = await _dio.postUri(
      routes.setTenantStatus(slug),
      data: {'status': status.value},
      options: Options(contentType: _json),
    );
    if (!_is2xx(r.statusCode)) _bad(r, 'Set tenant status');
    invalidateCache();
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
    invalidateCache();
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
    invalidateCache();
  }

  Future<void> _transferOwner({
    required String slug,
    required Map<String, dynamic> payload,
  }) async {
    final r = await _dio.postUri(
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

  /// Persist a web asset URL into tenant assets and bump cache version.
  ///
  /// This is the ONLY supported way to update favicon / PWA icons.
  /// The URL MUST be a web-safe https:// URL (Firebase download URL).
  Future<void> updateTenantWebAsset({
    required String slug,
    required String assetKey, // 'favicon' | 'icon192' | 'icon512'
    required String downloadUrl,
  }) async {
    if (!downloadUrl.startsWith('http')) {
      throw ArgumentError(
        'downloadUrl must be a web-safe https URL',
        'downloadUrl',
      );
    }

    // Fetch current profile (cached or network)
    final profile = await getTenantProfile(slug);

    final currentAssets = profile.assets;

    final newLogos = {...currentAssets.logos, assetKey: downloadUrl};

    final updatedAssets = {
      'bucket': currentAssets.bucket,
      'version': currentAssets.version + 1, // 🔥 cache bust
      'logos': newLogos,
    };

    await updateTenantProfile(slug: slug, assets: updatedAssets);

    if (kDebugMode) {
      debugPrint(
        '✅ $_tag Web asset updated: $slug → $assetKey (v${currentAssets.version + 1})',
      );
    }
  }
}
