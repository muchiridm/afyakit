// lib/features/hq/apps/services/app_profile_service.dart

import 'dart:convert';

import 'package:afyakit/app/models/zoho_app_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/models/app_profile.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/shared/utils/utils.dart';

final appProfileServiceProvider = FutureProvider<AppProfileService>((
  ref,
) async {
  final client = await ref.watch(afyakitClientFutureProvider.future);

  // HQ routes are core-scoped.
  // The constructor still requires a tenantId to derive the core API base,
  // but this value does not become the target tenant.
  const hqId = 'afyakit';

  return AppProfileService(dio: client.dio, routes: AfyaKitRoutes(hqId));
});

class AppProfileService {
  AppProfileService({required Dio dio, required this.routes}) : _dio = dio;

  final Dio _dio;
  final AfyaKitRoutes routes;

  static const String _tag = '[AppProfileService]';

  static const String _json = Headers.jsonContentType;

  // ─────────────────────────────────────────────
  // List
  // ─────────────────────────────────────────────

  Future<List<AppProfile>> fetchAppProfiles({required String tenantId}) async {
    final cleanTenantId = _cleanId(tenantId, fieldName: 'tenantId');

    final response = await _dio.getUri(routes.listTenantApps(cleanTenantId));

    _ensureSuccess(response, 'List apps');

    final items = _asList(response.data);

    final profiles =
        items.map((raw) {
          final appId = _readAppId(raw);

          if (appId.isEmpty) {
            throw StateError('App response is missing appId');
          }

          return AppProfile.fromFirestore(appId, raw);
        }).toList()..sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );

    if (kDebugMode) {
      debugPrint(
        '✅ $_tag Loaded ${profiles.length} apps '
        'for tenant "$cleanTenantId"',
      );
    }

    return profiles;
  }

  // ─────────────────────────────────────────────
  // Get
  // ─────────────────────────────────────────────

  Future<AppProfile> getAppProfile({
    required String tenantId,
    required String appId,
  }) async {
    final cleanTenantId = _cleanId(tenantId, fieldName: 'tenantId');

    final cleanAppId = _cleanId(appId, fieldName: 'appId');

    final response = await _dio.getUri(
      routes.getTenantApp(cleanTenantId, cleanAppId),
    );

    _ensureSuccess(response, 'Get app');

    final raw = _asMap(response.data);

    return AppProfile.fromFirestore(
      _readAppId(raw).isNotEmpty ? _readAppId(raw) : cleanAppId,
      raw,
    );
  }

  // ─────────────────────────────────────────────
  // Create
  // ─────────────────────────────────────────────

  Future<AppProfile> createAppProfile({
    required String tenantId,
    required String appId,
    required String displayName,
    String primaryColorHex = '#2196F3',
    Map<String, bool> features = const <String, bool>{},
    JsonObj assets = const <String, dynamic>{},
    JsonObj profile = const <String, dynamic>{},
    bool active = true,
  }) async {
    final cleanTenantId = _cleanId(tenantId, fieldName: 'tenantId');

    final cleanAppId = _cleanId(appId, fieldName: 'appId');

    final name = displayName.trim();

    if (name.isEmpty) {
      throw ArgumentError.value(
        displayName,
        'displayName',
        'displayName cannot be empty',
      );
    }

    final color = primaryColorHex.trim();

    final payload = <String, dynamic>{
      'appId': cleanAppId,
      'displayName': name,
      'primaryColorHex': color.isEmpty ? '#2196F3' : color,
      'features': features,
      'assets': assets,
      'profile': profile,
      'status': active ? 'active' : 'inactive',
    };

    final response = await _dio.postUri(
      routes.createTenantApp(cleanTenantId),
      data: payload,
      options: Options(contentType: _json),
    );

    _ensureSuccess(response, 'Create app');

    final raw = _asMap(response.data);

    final created = AppProfile.fromFirestore(
      _readAppId(raw).isNotEmpty ? _readAppId(raw) : cleanAppId,
      raw,
    );

    if (kDebugMode) {
      debugPrint(
        '✅ $_tag Created '
        '"$cleanTenantId/$cleanAppId"',
      );
    }

    return created;
  }

  // ─────────────────────────────────────────────
  // Update
  // ─────────────────────────────────────────────

  Future<AppProfile> updateAppProfile({
    required String tenantId,
    required String appId,
    String? displayName,
    String? primaryColorHex,
    Map<String, bool>? features,
    JsonObj? assets,
    JsonObj? profile,
    bool? active,
  }) async {
    final cleanTenantId = _cleanId(tenantId, fieldName: 'tenantId');

    final cleanAppId = _cleanId(appId, fieldName: 'appId');

    final payload = <String, dynamic>{
      if (displayName != null) 'displayName': displayName.trim(),
      if (primaryColorHex != null) 'primaryColorHex': primaryColorHex.trim(),
      if (features != null) 'features': features,
      if (assets != null) 'assets': assets,
      if (profile != null) 'profile': profile,
      if (active != null) 'status': active ? 'active' : 'inactive',
    };

    if (payload.isEmpty) {
      return getAppProfile(tenantId: cleanTenantId, appId: cleanAppId);
    }

    final response = await _dio.patchUri(
      routes.updateTenantApp(cleanTenantId, cleanAppId),
      data: payload,
      options: Options(contentType: _json),
    );

    _ensureSuccess(response, 'Update app');

    final raw = _asMap(response.data);

    final updated = AppProfile.fromFirestore(
      _readAppId(raw).isNotEmpty ? _readAppId(raw) : cleanAppId,
      raw,
    );

    if (kDebugMode) {
      debugPrint(
        '✅ $_tag Updated '
        '"$cleanTenantId/$cleanAppId"',
      );
    }

    return updated;
  }

  // ─────────────────────────────────────────────
  // Delete
  // ─────────────────────────────────────────────

  Future<void> deleteAppProfile({
    required String tenantId,
    required String appId,
  }) async {
    final cleanTenantId = _cleanId(tenantId, fieldName: 'tenantId');

    final cleanAppId = _cleanId(appId, fieldName: 'appId');

    final response = await _dio.deleteUri(
      routes.deleteTenantApp(cleanTenantId, cleanAppId),
    );

    final status = response.statusCode;

    if (status != 204 && !_is2xx(status)) {
      _bad(response, 'Delete app');
    }

    if (kDebugMode) {
      debugPrint(
        '🗑️ $_tag Deleted '
        '"$cleanTenantId/$cleanAppId"',
      );
    }
  }

  // ─────────────────────────────────────────────
  // Branding asset metadata
  // ─────────────────────────────────────────────

  Future<AppProfile> updateAppWebAsset({
    required String tenantId,
    required String appId,
    required String assetKey,
    required String downloadUrl,
  }) async {
    final key = assetKey.trim();
    final url = downloadUrl.trim();

    if (key.isEmpty) {
      throw ArgumentError.value(
        assetKey,
        'assetKey',
        'assetKey cannot be empty',
      );
    }

    if (!url.startsWith('https://') && !url.startsWith('http://')) {
      throw ArgumentError.value(
        downloadUrl,
        'downloadUrl',
        'downloadUrl must be a web-safe HTTP(S) URL',
      );
    }

    final current = await getAppProfile(tenantId: tenantId, appId: appId);

    final logos = Map<String, String>.from(current.assets.logos);

    logos[key] = url;

    return updateAppProfile(
      tenantId: tenantId,
      appId: appId,
      assets: <String, dynamic>{
        'bucket': current.assets.bucket,
        'version': current.assets.version + 1,
        'logos': logos,
      },
    );
  }

  Future<ZohoAppConfig> getZohoConfig({
    required String tenantId,
    required String appId,
  }) async {
    final cleanTenantId = _cleanId(tenantId, fieldName: 'tenantId');

    final cleanAppId = _cleanId(appId, fieldName: 'appId');

    final response = await _dio.getUri(
      routes.getTenantAppZoho(cleanTenantId, cleanAppId),
    );

    _ensureSuccess(response, 'Get Zoho Books configuration');

    return ZohoAppConfig.fromMap(_asMap(response.data));
  }

  Future<ZohoAppConfig> saveZohoConfig({
    required String tenantId,
    required String appId,
    required bool enabled,
    required String? organisationId,
  }) async {
    final cleanTenantId = _cleanId(tenantId, fieldName: 'tenantId');

    final cleanAppId = _cleanId(appId, fieldName: 'appId');

    final response = await _dio.putUri(
      routes.getTenantAppZoho(cleanTenantId, cleanAppId),
      data: <String, dynamic>{
        'enabled': enabled,
        'organisationId': organisationId?.trim().isEmpty == true
            ? null
            : organisationId?.trim(),
      },
      options: Options(contentType: _json),
    );

    _ensureSuccess(response, 'Save Zoho Books configuration');

    return ZohoAppConfig.fromMap(_asMap(response.data));
  }

  Future<void> deleteZohoConfig({
    required String tenantId,
    required String appId,
  }) async {
    final cleanTenantId = _cleanId(tenantId, fieldName: 'tenantId');

    final cleanAppId = _cleanId(appId, fieldName: 'appId');

    final response = await _dio.deleteUri(
      routes.getTenantAppZoho(cleanTenantId, cleanAppId),
    );

    final status = response.statusCode;

    if (status != 204 && !_is2xx(status)) {
      _bad(response, 'Delete Zoho Books configuration');
    }
  }

  // ─────────────────────────────────────────────
  // Response helpers
  // ─────────────────────────────────────────────

  bool _is2xx(int? status) {
    return status != null && status >= 200 && status < 300;
  }

  void _ensureSuccess(Response<dynamic> response, String operation) {
    if (!_is2xx(response.statusCode)) {
      _bad(response, operation);
    }
  }

  Never _bad(Response<dynamic> response, String operation) {
    final body = _asMap(response.data);

    final code = body['error']?.toString().trim();

    final message = body['message']?.toString().trim();

    final reason = [
      if (code != null && code.isNotEmpty) code,
      if (message != null && message.isNotEmpty) message,
    ].join(': ');

    throw StateError(
      '$operation failed '
      '(${response.statusCode})'
      '${reason.isNotEmpty ? ': $reason' : ''}',
    );
  }

  JsonObj _asMap(Object? raw) {
    if (raw is JsonObj) {
      return raw;
    }

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);

        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Fall through.
      }
    }

    return const <String, dynamic>{};
  }

  List<JsonObj> _asList(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    final map = _asMap(raw);

    final items = map['items'] ?? map['results'] ?? map['apps'] ?? map['data'];

    if (items is! List) {
      return const <JsonObj>[];
    }

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _readAppId(JsonObj raw) {
    return (raw['appId'] ?? raw['id'] ?? '').toString().trim().toLowerCase();
  }

  String _cleanId(String value, {required String fieldName}) {
    final clean = value.trim().toLowerCase();

    if (clean.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName cannot be empty');
    }

    return clean;
  }
}
