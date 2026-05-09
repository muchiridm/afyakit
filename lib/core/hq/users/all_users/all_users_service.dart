// lib/hq/users/all_users/all_users_service.dart

import 'dart:convert';

import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/core/hq/users/all_users/all_user_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// DI: builds service with tenant-scoped routes + Dio from AfyaKitClient.
final allUsersServiceProvider = FutureProvider.autoDispose<AllUsersService>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  final client = await ref.watch(afyakitClientFutureProvider.future);
  final routes = AfyaKitRoutes(tenantId);

  return AllUsersService(dio: client.dio, routes: routes);
});

class AllUsersService {
  AllUsersService({required this.dio, required this.routes});

  final Dio dio;
  final AfyaKitRoutes routes;

  static const _tag = '[AllUsersService]';

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────

  bool _ok(Response<dynamic> r) => ((r.statusCode ?? 0) ~/ 100) == 2;

  Never _bad(Response<dynamic> r, String op) {
    final status = r.statusCode ?? 0;
    final data = r.data;

    String? reason;

    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final err = m['error'] ?? m['message'];
      if (err != null) reason = err.toString();
    } else if (data is String && data.trim().isNotEmpty) {
      reason = data.trim();
    } else if (r.statusMessage != null && r.statusMessage!.trim().isNotEmpty) {
      reason = r.statusMessage!.trim();
    }

    throw Exception(
      '❌ $op failed ($status)${reason != null ? ': $reason' : ''}',
    );
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);

    final enc = jsonEncode(raw);
    final dec = jsonDecode(enc);

    if (dec is! Map) {
      throw Exception('❌ Expected response object but got ${dec.runtimeType}');
    }

    return Map<String, dynamic>.from(dec);
  }

  /// Normalize unknown API shapes into `List<Map<String, dynamic>>`.
  ///
  /// Supported:
  /// - [...]
  /// - { users: [...] }
  /// - { results: [...] }
  /// - { items: [...] }
  /// - { data: [...] }
  List<Map<String, dynamic>> _extractList(Object? raw) {
    if (raw == null) return const <Map<String, dynamic>>[];

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);

      for (final key in const ['users', 'results', 'items', 'data']) {
        final v = m[key];

        if (v is List) {
          return v
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      final values = m.values.toList();

      if (values.isNotEmpty && values.every((v) => v is Map)) {
        return values
            .cast<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    return const <Map<String, dynamic>>[];
  }

  static String _normId(Object? v) {
    return v?.toString().trim() ?? '';
  }

  AllUser _userFromMap(Map<String, dynamic> m) {
    final id = _normId(m['id'] ?? m['uid']);

    if (id.isEmpty) {
      throw Exception('❌ User row missing id/uid');
    }

    return AllUser.fromJson(id, Map<String, Object?>.from(m));
  }

  /// Backend patch returns: { user: {...}, zoho?: {...} }.
  /// Some GETs return the user directly. Normalize both.
  AllUser _userFromResponse(Response<dynamic> r) {
    final top = _asMap(r.data);

    final rawUser = top['user'] is Map
        ? Map<String, dynamic>.from(top['user'] as Map)
        : top;

    return _userFromMap(rawUser);
  }

  // ─────────────────────────────────────────────────────────────
  // HQ Directory
  // ─────────────────────────────────────────────────────────────

  /// GET /api/users
  ///
  /// Should return users WITH memberships already embedded.
  ///
  /// The frontend should not call `/api/users/:uid/memberships`
  /// for every row after this.
  Future<List<AllUser>> fetchAllUsers({
    String? tenantId,
    String search = '',
    int limit = 50,
  }) async {
    final q = search.trim();

    final uri = routes.listGlobalUsers(
      tenant: tenantId?.trim().isNotEmpty == true ? tenantId!.trim() : null,
      search: q.isEmpty ? null : q,
      limit: limit,
    );

    if (kDebugMode) debugPrint('🛰️ $_tag GET $uri');

    final r = await dio.getUri(uri);
    if (!_ok(r)) _bad(r, 'List users');

    final items = _extractList(r.data);
    final users = items.map(_userFromMap).toList();

    if (kDebugMode) {
      debugPrint(
        '✅ $_tag parsed ${users.length} users with embedded memberships',
      );
    }

    return users;
  }

  /// GET /api/users/:uid/memberships
  ///
  /// Keep this only for:
  /// - user detail page manual refresh
  /// - manual repair/debug view
  /// - fallback if a specific user is opened and memberships are absent
  Future<Map<String, AllUserMembership>> fetchUserMemberships(
    String uid,
  ) async {
    final cleanUid = uid.trim();

    if (cleanUid.isEmpty) {
      throw Exception('❌ Fetch memberships: uid is required');
    }

    final uri = routes.fetchUserMemberships(cleanUid);

    if (kDebugMode) debugPrint('🛰️ $_tag GET $uri');

    final r = await dio.getUri(uri);
    if (!_ok(r)) _bad(r, 'Fetch memberships');

    final data = _asMap(r.data);
    final raw = data.containsKey('memberships') ? data['memberships'] : r.data;

    final out = <String, AllUserMembership>{};

    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);

      m.forEach((tenantId, value) {
        if (value is! Map) return;

        final row = Map<String, Object?>.from(value);
        row['tenantId'] = tenantId.toString();

        final membership = AllUserMembership.fromJson(row);

        if (membership.tenantId.trim().isNotEmpty) {
          out[membership.tenantId] = membership;
        }
      });

      return out;
    }

    if (raw is List) {
      for (final item in raw.whereType<Map>()) {
        final row = Map<String, Object?>.from(item);
        final membership = AllUserMembership.fromJson(row);

        if (membership.tenantId.trim().isNotEmpty) {
          out[membership.tenantId] = membership;
        }
      }
    }

    return out;
  }

  /// DELETE /api/users/:uid
  ///
  /// Deletes a global unassigned/orphan user.
  ///
  /// Backend should refuse this if tenant SOT records still exist:
  /// - tenants/{tenantId}/auth_users/{uid}
  ///
  /// Stale mirror edges under users/{uid}/memberships may be cleaned server-side.
  Future<void> hqDeleteGlobalUser(String uid) async {
    final cleanUid = uid.trim();

    if (cleanUid.isEmpty) {
      throw Exception('❌ Delete global user: uid is required');
    }

    final uri = routes.deleteGlobalUser(cleanUid);

    if (kDebugMode) debugPrint('🛰️ $_tag DELETE $uri');

    final r = await dio.deleteUri(uri);
    final ok = r.statusCode == 200 || r.statusCode == 204 || _ok(r);

    if (!ok) _bad(r, 'Delete global user');

    if (kDebugMode) {
      debugPrint('🗑️ $_tag Deleted global user uid=$cleanUid');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HQ Tenant auth_users cross-tenant management
  // ─────────────────────────────────────────────────────────────

  /// GET /api/tenants/:tenantId/auth_users
  ///
  /// Tenant SOT-facing endpoint. Reads from:
  /// tenants/{tenantId}/auth_users
  Future<List<AllUser>> hqFetchTenantUsers(
    String targetTenantId, {
    String search = '',
    int limit = 50,
  }) async {
    final cleanTenantId = targetTenantId.trim();

    if (cleanTenantId.isEmpty) {
      throw Exception('❌ HQ list tenant users: targetTenantId is required');
    }

    final q = search.trim();

    final uri = routes.hqListTenantUsers(
      cleanTenantId,
      search: q.isEmpty ? null : q,
      limit: limit,
    );

    if (kDebugMode) debugPrint('🛰️ $_tag GET $uri');

    final r = await dio.getUri(uri);
    if (!_ok(r)) _bad(r, 'HQ list tenant users');

    final items = _extractList(r.data);
    final users = items.map(_userFromMap).toList();

    if (kDebugMode) {
      debugPrint(
        '✅ $_tag parsed ${users.length} tenant users for tenant=$cleanTenantId',
      );
    }

    return users;
  }

  /// POST /api/tenants/:tenantId/auth_users
  ///
  /// Body:
  /// { phoneNumber, displayName? }
  ///
  /// Returns raw PatchAuthUserResult:
  /// { user, zoho? }
  Future<Map<String, Object?>> hqCreateTenantUser({
    required String targetTenantId,
    required String phoneNumber,
    String? displayName,
  }) async {
    final cleanTenantId = targetTenantId.trim();
    final phone = phoneNumber.trim();
    final dn = displayName?.trim();

    if (cleanTenantId.isEmpty) {
      throw Exception('❌ HQ create tenant user: targetTenantId is required');
    }

    if (phone.isEmpty) {
      throw Exception('❌ HQ create tenant user: phoneNumber is required');
    }

    final uri = routes.hqCreateTenantUser(cleanTenantId);

    if (kDebugMode) debugPrint('🛰️ $_tag POST $uri');

    final body = <String, Object?>{
      'phoneNumber': phone,
      if (dn != null && dn.isNotEmpty) 'displayName': dn,
    };

    if (kDebugMode) debugPrint('📦 $_tag POST payload=$body');

    final r = await dio.postUri(
      uri,
      data: body,
      options: Options(contentType: Headers.jsonContentType),
    );

    if (!_ok(r)) _bad(r, 'HQ create tenant user');

    return Map<String, Object?>.from(_asMap(r.data));
  }

  /// GET /api/tenants/:tenantId/auth_users/:uid
  Future<AllUser> hqGetTenantUserById(String targetTenantId, String uid) async {
    final cleanTenantId = targetTenantId.trim();
    final cleanUid = uid.trim();

    if (cleanTenantId.isEmpty) {
      throw Exception('❌ HQ get tenant user: targetTenantId is required');
    }

    if (cleanUid.isEmpty) {
      throw Exception('❌ HQ get tenant user: uid is required');
    }

    final uri = routes.hqGetTenantUserById(cleanTenantId, cleanUid);

    if (kDebugMode) debugPrint('🛰️ $_tag GET $uri');

    final r = await dio.getUri(uri);
    if (!_ok(r)) _bad(r, 'HQ get tenant user');

    return _userFromResponse(r);
  }

  /// PATCH /api/tenants/:tenantId/auth_users/:uid
  ///
  /// Backend PatchAuthUserSchema supports:
  /// - status
  /// - displayName
  /// - avatarUrl
  /// - stores
  /// - staffRoles[]
  /// - isCompany
  /// - companyName
  /// - firstName
  /// - lastName
  ///
  /// Important:
  /// Do not send legacy `type`. Staff access is controlled only by staffRoles.
  Future<Map<String, Object?>> hqPatchTenantUser({
    required String targetTenantId,
    required String uid,
    required Map<String, Object?> patch,
  }) async {
    final cleanTenantId = targetTenantId.trim();
    final cleanUid = uid.trim();

    if (cleanTenantId.isEmpty) {
      throw Exception('❌ HQ patch tenant user: targetTenantId is required');
    }

    if (cleanUid.isEmpty) {
      throw Exception('❌ HQ patch tenant user: uid is required');
    }

    if (patch.isEmpty) {
      throw Exception('❌ HQ patch tenant user: no fields to update');
    }

    final uri = routes.hqPatchTenantUser(cleanTenantId, cleanUid);

    if (kDebugMode) {
      debugPrint('🛰️ $_tag PATCH $uri');
      debugPrint('📦 $_tag PATCH payload=$patch');
    }

    final r = await dio.patchUri(
      uri,
      data: patch,
      options: Options(contentType: Headers.jsonContentType),
    );

    if (!_ok(r)) _bad(r, 'HQ patch tenant user');

    return Map<String, Object?>.from(_asMap(r.data));
  }

  /// DELETE /api/tenants/:tenantId/auth_users/:uid
  Future<void> hqDeleteTenantUser({
    required String targetTenantId,
    required String uid,
  }) async {
    final cleanTenantId = targetTenantId.trim();
    final cleanUid = uid.trim();

    if (cleanTenantId.isEmpty) {
      throw Exception('❌ HQ delete tenant user: targetTenantId is required');
    }

    if (cleanUid.isEmpty) {
      throw Exception('❌ HQ delete tenant user: uid is required');
    }

    final uri = routes.hqDeleteTenantUser(cleanTenantId, cleanUid);

    if (kDebugMode) debugPrint('🛰️ $_tag DELETE $uri');

    final r = await dio.deleteUri(uri);
    final ok = r.statusCode == 204 || _ok(r);

    if (!ok) _bad(r, 'HQ delete tenant user');

    if (kDebugMode) {
      debugPrint('🗑️ $_tag Removed uid=$cleanUid from tenant=$cleanTenantId');
    }
  }
}
