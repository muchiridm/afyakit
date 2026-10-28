// lib/features/hq/tenants/services/tenant_service.dart

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/tenancy/models/tenant_profile.dart';
import 'package:afyakit/core/tenancy/models/tenant_status_x.dart';
import 'package:afyakit/shared/utils/utils.dart';

final tenantServiceProvider = FutureProvider<TenantService>((ref) async {
  final client = await ref.watch(afyakitClientFutureProvider.future);

  const hqId = 'afyakit';

  return TenantService(dio: client.dio, routes: AfyaKitRoutes(hqId));
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

  static const String _json = Headers.jsonContentType;

  static const String _tag = '[TenantService]';

  Future<List<TenantProfile>>? _inflightList;

  List<TenantProfile>? _cachedList;

  DateTime? _cachedAt;

  Duration _listCacheTtl;

  Duration get listCacheTtl => _listCacheTtl;

  void setListCacheTtl(Duration ttl) {
    _listCacheTtl = ttl;
  }

  void invalidateCache() {
    _cachedList = null;
    _cachedAt = null;
  }

  bool _is2xx(int? status) {
    return status != null && status >= 200 && status < 300;
  }

  Never _bad(Response<dynamic> response, String operation) {
    final reason = response.data is Map
        ? (response.data as Map)['error']
        : null;

    throw Exception(
      '❌ $operation failed '
      '(${response.statusCode}): '
      '${reason ?? 'Unknown'}',
    );
  }

  JsonObj _asMap(Object? raw) {
    if (raw is JsonObj) {
      return raw;
    }

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return Map<String, dynamic>.from(jsonDecode(jsonEncode(raw)));
  }

  List<JsonObj> _asList(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    final map = _asMap(raw);

    final list =
        map['results'] ?? map['items'] ?? map['tenants'] ?? map['data'];

    if (list is! List) {
      return const <JsonObj>[];
    }

    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<TenantProfile>> fetchTenantProfiles({bool forceRefresh = false}) {
    final now = DateTime.now();

    if (!forceRefresh && _listCacheTtl > Duration.zero) {
      final cached = _cachedList;

      final cachedAt = _cachedAt;

      if (cached != null && cachedAt != null) {
        if (now.difference(cachedAt) <= _listCacheTtl) {
          return Future.value(cached);
        }
      }
    }

    final inflight = _inflightList;

    if (!forceRefresh && inflight != null) {
      return inflight;
    }

    final future = _fetchTenantProfilesNetwork().whenComplete(() {
      _inflightList = null;
    });

    _inflightList = future;

    return future;
  }

  Future<List<TenantProfile>> _fetchTenantProfilesNetwork() async {
    final response = await _dio.getUri(routes.listTenants());

    if (!_is2xx(response.statusCode)) {
      _bad(response, 'List tenants');
    }

    final profiles = _asList(response.data).mapIndexed((index, map) {
      final tenantId = (map['tenantId'] ?? map['id'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      return TenantProfile.fromFirestore(tenantId, map);
    }).toList();

    _cachedList = profiles;

    _cachedAt = DateTime.now();

    if (kDebugMode) {
      debugPrint(
        '✅ $_tag Loaded '
        '${profiles.length} tenants',
      );
    }

    return profiles;
  }

  Future<List<TenantProfile>> listTenantProfiles() {
    return fetchTenantProfiles();
  }

  Future<TenantProfile> getTenantProfile(String tenantId) async {
    final cleanTenantId = _sanitizeId(tenantId);

    final response = await _dio.getUri(routes.getTenant(cleanTenantId));

    if (!_is2xx(response.statusCode)) {
      _bad(response, 'Get tenant');
    }

    return TenantProfile.fromFirestore(cleanTenantId, _asMap(response.data));
  }

  Future<String> createTenantProfile({
    required String tenantId,
    Map<String, bool> features = const <String, bool>{},
    TenantStatus status = TenantStatus.active,
  }) async {
    final cleanTenantId = _sanitizeId(tenantId);

    final payload = <String, dynamic>{
      'tenantId': cleanTenantId,
      'features': features,
      'status': status.value,
    };

    final response = await _dio.postUri(
      routes.createTenant(),
      data: payload,
      options: Options(contentType: _json),
    );

    if (!_is2xx(response.statusCode)) {
      _bad(response, 'Create tenant');
    }

    invalidateCache();

    final body = _asMap(response.data);

    final createdTenantId = (body['tenantId'] ?? body['id'] ?? cleanTenantId)
        .toString()
        .trim()
        .toLowerCase();

    if (kDebugMode) {
      debugPrint(
        '✅ $_tag Tenant created: '
        '$createdTenantId',
      );
    }

    return createdTenantId;
  }

  Future<void> updateTenantProfile({
    required String tenantId,
    Map<String, bool>? features,
    TenantStatus? status,
  }) async {
    final cleanTenantId = _sanitizeId(tenantId);

    final payload = <String, dynamic>{
      if (features != null) 'features': features,
      if (status != null) 'status': status.value,
    };

    if (payload.isEmpty) {
      return;
    }

    final response = await _dio.patchUri(
      routes.updateTenant(cleanTenantId),
      data: payload,
      options: Options(contentType: _json),
    );

    if (!_is2xx(response.statusCode)) {
      _bad(response, 'Update tenant');
    }

    invalidateCache();

    if (kDebugMode) {
      debugPrint(
        '✅ $_tag Tenant '
        '$cleanTenantId updated',
      );
    }
  }

  Future<void> deleteTenantProfile(String tenantId, {bool hard = false}) async {
    final cleanTenantId = _sanitizeId(tenantId);

    final uri = hard
        ? routes
              .deleteTenant(cleanTenantId)
              .replace(queryParameters: {'hard': '1'})
        : routes.deleteTenant(cleanTenantId);

    final response = await _dio.deleteUri(uri);

    final ok = response.statusCode == 204 || _is2xx(response.statusCode);

    if (!ok) {
      _bad(response, 'Delete tenant');
    }

    invalidateCache();

    if (kDebugMode) {
      debugPrint(
        '🗑️ $_tag Tenant deleted: '
        '$cleanTenantId '
        '(hard=$hard)',
      );
    }
  }

  Future<void> setStatus(String tenantId, TenantStatus status) async {
    final cleanTenantId = _sanitizeId(tenantId);

    final response = await _dio.postUri(
      routes.setTenantStatus(cleanTenantId),
      data: {'status': status.value},
      options: Options(contentType: _json),
    );

    if (!_is2xx(response.statusCode)) {
      _bad(response, 'Set tenant status');
    }

    invalidateCache();
  }

  Future<void> setOwnerByEmail({
    required String tenantId,
    required String email,
  }) async {
    final target = email.trim();

    if (target.isEmpty) {
      throw ArgumentError.value(email, 'email', 'must not be empty');
    }

    await _transferOwner(
      tenantId: _sanitizeId(tenantId),
      payload: {'email': target},
    );

    invalidateCache();
  }

  Future<void> setOwnerByUid({
    required String tenantId,
    required String uid,
  }) async {
    final target = uid.trim();

    if (target.isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'must not be empty');
    }

    await _transferOwner(
      tenantId: _sanitizeId(tenantId),
      payload: {'uid': target},
    );

    invalidateCache();
  }

  Future<void> _transferOwner({
    required String tenantId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _dio.postUri(
      routes.setTenantOwner(tenantId),
      data: payload,
      options: Options(
        contentType: Headers.jsonContentType,
        validateStatus: (status) => status != null && status < 500,
        receiveDataWhenStatusError: true,
      ),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final body = _asMap(response.data);

      throw Exception(
        '${body['error'] ?? 'error'}: '
        '${body['message'] ?? 'Request failed'}',
      );
    }
  }

  String _sanitizeId(String input) {
    final value = input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s_-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    return value.isNotEmpty ? value : 'tenant';
  }
}
