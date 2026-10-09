// lib/features/hq/users/all_users/all_users_service.dart

import 'dart:convert';

import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/features/hq/users/all_users/all_user_model.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// HQ user-directory service.
///
/// Global users are managed through:
///
///   /api/hq/users
///
/// Tenant auth users are managed through each tenant's auth namespace:
///
///   /api/:tenantId/auth/users
final allUsersServiceProvider = FutureProvider.autoDispose<AllUsersService>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);

  final client = await ref.watch(afyakitClientFutureProvider.future);

  return AllUsersService(dio: client.dio, routes: AfyaKitRoutes(tenantId));
});

class AllUsersService {
  AllUsersService({required this.dio, required this.routes});

  final Dio dio;
  final AfyaKitRoutes routes;

  static const String _tag = '[AllUsersService]';

  // ─────────────────────────────────────────────
  // Response helpers
  // ─────────────────────────────────────────────

  bool _ok(Response<dynamic> response) {
    final status = response.statusCode ?? 0;

    return status >= 200 && status < 300;
  }

  Never _bad(Response<dynamic> response, String operation) {
    final status = response.statusCode ?? 0;

    final data = response.data;

    String? reason;

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);

      final raw = map['error'] ?? map['message'];

      if (raw != null) {
        reason = raw.toString().trim();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      reason = data.trim();
    } else {
      final statusMessage = response.statusMessage?.trim();

      if (statusMessage != null && statusMessage.isNotEmpty) {
        reason = statusMessage;
      }
    }

    throw Exception(
      '❌ $operation failed ($status)'
      '${reason != null && reason.isNotEmpty ? ': $reason' : ''}',
    );
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    final encoded = jsonEncode(raw);

    final decoded = jsonDecode(encoded);

    if (decoded is! Map) {
      throw Exception(
        '❌ Expected response object '
        'but got ${decoded.runtimeType}',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  List<Map<String, dynamic>> _extractList(Object? raw) {
    if (raw == null) {
      return const <Map<String, dynamic>>[];
    }

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);

      for (final key in const ['users', 'results', 'items', 'data']) {
        final value = map[key];

        if (value is List) {
          return value
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }

      final values = map.values.toList();

      if (values.isNotEmpty && values.every((value) => value is Map)) {
        return values
            .cast<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }

    return const <Map<String, dynamic>>[];
  }

  static String _normId(Object? value) {
    return value?.toString().trim() ?? '';
  }

  AllUser _userFromMap(Map<String, dynamic> map) {
    final id = _normId(map['id'] ?? map['uid']);

    if (id.isEmpty) {
      throw Exception('❌ User row missing id/uid');
    }

    return AllUser.fromJson(id, Map<String, Object?>.from(map));
  }

  /// Backend user mutations may return:
  ///
  /// { user: {...}, zoho?: {...} }
  ///
  /// while GET endpoints may return the user directly.
  AllUser _userFromResponse(Response<dynamic> response) {
    final top = _asMap(response.data);

    final user = top['user'];

    final raw = user is Map ? Map<String, dynamic>.from(user) : top;

    return _userFromMap(raw);
  }

  String _requireId(String value, String fieldName) {
    final clean = value.trim();

    if (clean.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName is required');
    }

    return clean;
  }

  AfyaKitRoutes _tenantRoutes(String tenantId) {
    return AfyaKitRoutes(_requireId(tenantId, 'tenantId'));
  }

  // ═════════════════════════════════════════════
  // HQ global user directory
  // /api/hq/users
  // ═════════════════════════════════════════════

  /// GET /api/hq/users
  ///
  /// Expected to return users with memberships embedded.
  Future<List<AllUser>> fetchAllUsers({
    String? tenantId,
    String search = '',
    int limit = 50,
  }) async {
    final query = search.trim();

    final uri = routes.listGlobalUsers(
      tenant: tenantId?.trim().isNotEmpty == true ? tenantId!.trim() : null,
      search: query.isEmpty ? null : query,
      limit: limit,
    );

    if (kDebugMode) {
      debugPrint('🛰️ $_tag GET $uri');
    }

    final response = await dio.getUri(uri);

    if (!_ok(response)) {
      _bad(response, 'List global users');
    }

    final users = _extractList(response.data).map(_userFromMap).toList();

    if (kDebugMode) {
      debugPrint(
        '✅ $_tag Parsed ${users.length} '
        'global users',
      );
    }

    return users;
  }

  /// GET /api/hq/users/:uid/memberships
  Future<Map<String, AllUserMembership>> fetchUserMemberships(
    String uid,
  ) async {
    final cleanUid = _requireId(uid, 'uid');

    final uri = routes.fetchUserMemberships(cleanUid);

    if (kDebugMode) {
      debugPrint('🛰️ $_tag GET $uri');
    }

    final response = await dio.getUri(uri);

    if (!_ok(response)) {
      _bad(response, 'Fetch user memberships');
    }

    final data = _asMap(response.data);

    final raw = data.containsKey('memberships')
        ? data['memberships']
        : response.data;

    final result = <String, AllUserMembership>{};

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);

      map.forEach((tenantId, value) {
        if (value is! Map) {
          return;
        }

        final row = Map<String, Object?>.from(value);

        row['tenantId'] = tenantId.toString();

        final membership = AllUserMembership.fromJson(row);

        if (membership.tenantId.trim().isNotEmpty) {
          result[membership.tenantId] = membership;
        }
      });

      return result;
    }

    if (raw is List) {
      for (final item in raw.whereType<Map>()) {
        final membership = AllUserMembership.fromJson(
          Map<String, Object?>.from(item),
        );

        if (membership.tenantId.trim().isNotEmpty) {
          result[membership.tenantId] = membership;
        }
      }
    }

    return result;
  }

  /// DELETE /api/hq/users/:uid
  ///
  /// Deletes a global orphan/unassigned user.
  Future<void> deleteGlobalUser(String uid) async {
    final cleanUid = _requireId(uid, 'uid');

    final uri = routes.deleteGlobalUser(cleanUid);

    if (kDebugMode) {
      debugPrint('🛰️ $_tag DELETE $uri');
    }

    final response = await dio.deleteUri(uri);

    if (!_ok(response)) {
      _bad(response, 'Delete global user');
    }

    if (kDebugMode) {
      debugPrint(
        '🗑️ $_tag Deleted global user '
        'uid=$cleanUid',
      );
    }
  }

  // ═════════════════════════════════════════════
  // Tenant auth users
  // /api/:tenantId/auth/users
  // ═════════════════════════════════════════════

  /// GET /api/:tenantId/auth/users
  Future<List<AllUser>> fetchTenantUsers(
    String tenantId, {
    String search = '',
    int limit = 50,
  }) async {
    final tenantRoutes = _tenantRoutes(tenantId);

    final query = search.trim();

    final uri = tenantRoutes.getAllUsers(
      search: query.isEmpty ? null : query,
      limit: limit,
    );

    if (kDebugMode) {
      debugPrint('🛰️ $_tag GET $uri');
    }

    final response = await dio.getUri(uri);

    if (!_ok(response)) {
      _bad(response, 'List tenant users');
    }

    final users = _extractList(response.data).map(_userFromMap).toList();

    if (kDebugMode) {
      debugPrint(
        '✅ $_tag Parsed ${users.length} '
        'tenant users for tenant=$tenantId',
      );
    }

    return users;
  }

  /// POST /api/:tenantId/auth/users
  Future<Map<String, Object?>> createTenantUser({
    required String tenantId,
    required String phoneNumber,
    String? displayName,
  }) async {
    final tenantRoutes = _tenantRoutes(tenantId);

    final phone = _requireId(phoneNumber, 'phoneNumber');

    final name = displayName?.trim();

    final uri = tenantRoutes.createUser();

    final body = <String, Object?>{
      'phoneNumber': phone,
      if (name != null && name.isNotEmpty) 'displayName': name,
    };

    if (kDebugMode) {
      debugPrint('🛰️ $_tag POST $uri');

      debugPrint('📦 $_tag POST payload=$body');
    }

    final response = await dio.postUri(
      uri,
      data: body,
      options: Options(contentType: Headers.jsonContentType),
    );

    if (!_ok(response)) {
      _bad(response, 'Create tenant user');
    }

    return Map<String, Object?>.from(_asMap(response.data));
  }

  /// GET /api/:tenantId/auth/users/:uid
  Future<AllUser> getTenantUserById({
    required String tenantId,
    required String uid,
  }) async {
    final tenantRoutes = _tenantRoutes(tenantId);

    final cleanUid = _requireId(uid, 'uid');

    final uri = tenantRoutes.getUserById(cleanUid);

    if (kDebugMode) {
      debugPrint('🛰️ $_tag GET $uri');
    }

    final response = await dio.getUri(uri);

    if (!_ok(response)) {
      _bad(response, 'Get tenant user');
    }

    return _userFromResponse(response);
  }

  /// Enable or disable a user's membership in one application.
  ///
  /// PUT /api/:tenantId/auth/users/:uid/apps/:appId/membership
  Future<void> setAppMembership({
    required String tenantId,
    required String uid,
    required String appId,
    required bool active,
  }) async {
    final cleanTenant = _requireId(tenantId, 'tenantId');
    final cleanUid = _requireId(uid, 'uid');
    final cleanApp = _requireId(appId, 'appId').toLowerCase();

    final tenantRoutes = _tenantRoutes(cleanTenant);
    final base = tenantRoutes.updateUser(cleanUid);

    final uri = base.replace(
      path: '${base.path}/apps/${Uri.encodeComponent(cleanApp)}/membership',
    );

    final response = await dio.putUri(
      uri,
      data: <String, Object?>{'status': active ? 'active' : 'disabled'},
      options: Options(contentType: Headers.jsonContentType),
    );

    if (!_ok(response)) {
      _bad(response, 'Update application membership');
    }

    if (kDebugMode) {
      debugPrint(
        '✅ $_tag App membership updated: '
        'tenant=$cleanTenant app=$cleanApp uid=$cleanUid '
        'active=$active',
      );
    }
  }

  /// Set staff roles for one application only.
  ///
  /// PUT /api/:tenantId/auth/users/:uid/apps/:appId/staff-roles
  ///
  /// An empty list means ordinary member access.
  Future<void> setAppStaffRoles({
    required String tenantId,
    required String uid,
    required String appId,
    required List<String> staffRoles,
  }) async {
    final cleanTenant = _requireId(tenantId, 'tenantId');
    final cleanUid = _requireId(uid, 'uid');
    final cleanApp = _requireId(appId, 'appId').toLowerCase();

    final allowedRoles = <String>{'manager', 'admin', 'owner'};

    final roles = staffRoles
        .map((role) => role.trim().toLowerCase())
        .toSet()
        .toList();

    if (roles.any((role) => !allowedRoles.contains(role))) {
      throw ArgumentError.value(
        staffRoles,
        'staffRoles',
        'Unsupported application staff role',
      );
    }

    final tenantRoutes = _tenantRoutes(cleanTenant);
    final base = tenantRoutes.updateUser(cleanUid);

    final uri = base.replace(
      path: '${base.path}/apps/${Uri.encodeComponent(cleanApp)}/staff-roles',
    );

    final response = await dio.putUri(
      uri,
      data: <String, Object?>{'staffRoles': roles},
      options: Options(contentType: Headers.jsonContentType),
    );

    if (!_ok(response)) {
      _bad(response, 'Update application staff roles');
    }

    if (kDebugMode) {
      debugPrint(
        '✅ $_tag App staff roles updated: '
        'tenant=$cleanTenant app=$cleanApp uid=$cleanUid '
        'roles=$roles',
      );
    }
  }

  /// PATCH /api/:tenantId/auth/users/:uid
  Future<Map<String, Object?>> updateTenantUser({
    required String tenantId,
    required String uid,
    required Map<String, Object?> patch,
  }) async {
    final tenantRoutes = _tenantRoutes(tenantId);

    final cleanUid = _requireId(uid, 'uid');

    if (patch.isEmpty) {
      throw ArgumentError.value(patch, 'patch', 'patch cannot be empty');
    }

    final uri = tenantRoutes.updateUser(cleanUid);

    if (kDebugMode) {
      debugPrint('🛰️ $_tag PATCH $uri');

      debugPrint('📦 $_tag PATCH payload=$patch');
    }

    final response = await dio.patchUri(
      uri,
      data: patch,
      options: Options(contentType: Headers.jsonContentType),
    );

    if (!_ok(response)) {
      _bad(response, 'Update tenant user');
    }

    return Map<String, Object?>.from(_asMap(response.data));
  }

  /// DELETE /api/:tenantId/auth/users/:uid
  Future<void> deleteTenantUser({
    required String tenantId,
    required String uid,
  }) async {
    final tenantRoutes = _tenantRoutes(tenantId);

    final cleanUid = _requireId(uid, 'uid');

    final uri = tenantRoutes.deleteUser(cleanUid);

    if (kDebugMode) {
      debugPrint('🛰️ $_tag DELETE $uri');
    }

    final response = await dio.deleteUri(uri);

    if (!_ok(response)) {
      _bad(response, 'Delete tenant user');
    }

    if (kDebugMode) {
      debugPrint(
        '🗑️ $_tag Removed uid=$cleanUid '
        'from tenant=$tenantId',
      );
    }
  }
}
