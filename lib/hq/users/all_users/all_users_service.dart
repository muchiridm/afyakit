// lib/hq/users/all_users/all_users_service.dart

import 'dart:convert';

import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/hq/users/all_users/all_user_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// DI: builds service with tenant-scoped routes + Dio from AfyaKitClient.
final allUsersServiceProvider = FutureProvider.autoDispose<AllUsersService>((
  ref,
) async {
  final tenantId = ref.watch(tenantSlugProvider);
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
    return Map<String, dynamic>.from(dec as Map);
  }

  /// Normalize unknown API shapes into `List<Map<String, dynamic>>`.
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

      for (final key in const [
        'users',
        'results',
        'items',
        'data',
        'memberships',
      ]) {
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
    final s = v?.toString().trim();
    return (s == null) ? '' : s;
  }

  AllUser _userFromMap(Map<String, dynamic> m) {
    final id = _normId(m['id'] ?? m['uid']);
    return AllUser.fromJson(id, Map<String, Object?>.from(m));
  }

  /// Backend patch returns: { user: {...}, zoho?: {...} }
  /// Some GETs return the user directly. Normalize both.
  AllUser _userFromResponse(Response<dynamic> r) {
    final top = _asMap(r.data);

    final rawUser = (top['user'] is Map)
        ? Map<String, dynamic>.from(top['user'] as Map)
        : top;

    final id = _normId(rawUser['id'] ?? rawUser['uid']);
    return AllUser.fromJson(id, Map<String, Object?>.from(rawUser));
  }

  // ─────────────────────────────────────────────────────────────
  // HQ Directory (READ-ONLY)
  // ─────────────────────────────────────────────────────────────

  /// GET /api/users
  Future<List<AllUser>> fetchAllUsers({
    String? tenantId,
    String search = '',
    int limit = 50,
  }) async {
    final q = search.trim();

    final uri = routes.listGlobalUsers(
      tenant: (tenantId != null && tenantId.trim().isNotEmpty)
          ? tenantId.trim()
          : null,
      search: q.isEmpty ? null : q,
      limit: limit,
    );

    if (kDebugMode) debugPrint('🛰️ $_tag GET $uri');
    final r = await dio.getUri(uri);
    if (!_ok(r)) _bad(r, 'List users');

    final items = _extractList(r.data);
    if (kDebugMode) debugPrint('✅ $_tag parsed ${items.length} users');
    return items.map(_userFromMap).toList();
  }

  /// GET /api/users/:uid/memberships
  Future<Map<String, Map<String, Object?>>> fetchUserMemberships(
    String uid,
  ) async {
    final uri = routes.fetchUserMemberships(uid);
    if (kDebugMode) debugPrint('🛰️ $_tag GET $uri');

    final r = await dio.getUri(uri);
    if (!_ok(r)) _bad(r, 'Fetch memberships');

    final data = _asMap(r.data);
    final raw = data.containsKey('memberships') ? data['memberships'] : r.data;

    final out = <String, Map<String, Object?>>{};

    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      m.forEach((tid, val) {
        final v = _asMap(val);
        out[tid.toString()] = {
          'role': v['role'],
          'active': v['active'] == true,
          if (v['email'] != null) 'email': v['email'],
        };
      });
      return out;
    }

    if (raw is List) {
      for (final e in raw.whereType<Map>()) {
        final v = Map<String, dynamic>.from(e);
        final tid = (v['tenantId'] ?? v['tenant'] ?? '').toString();
        if (tid.isEmpty) continue;
        out[tid] = {
          'role': v['role'],
          'active': v['active'] == true,
          if (v['email'] != null) 'email': v['email'],
        };
      }
    }

    return out;
  }

  // ─────────────────────────────────────────────────────────────
  // HQ Tenant auth_users (cross-tenant management)
  // ─────────────────────────────────────────────────────────────

  /// GET /api/tenants/:slug/auth_users
  Future<List<AllUser>> hqFetchTenantUsers(
    String targetTenantId, {
    String search = '',
    int limit = 50,
  }) async {
    final q = search.trim();

    final uri = routes.hqListTenantUsers(
      targetTenantId,
      search: q.isEmpty ? null : q,
      limit: limit,
    );

    if (kDebugMode) debugPrint('🛰️ $_tag GET $uri');
    final r = await dio.getUri(uri);
    if (!_ok(r)) _bad(r, 'HQ list tenant users');

    final items = _extractList(r.data);
    return items.map(_userFromMap).toList();
  }

  /// ✅ POST /api/tenants/:slug/auth_users
  /// body: { phoneNumber, displayName? }
  ///
  /// Returns raw PatchAuthUserResult: { user, zoho? }
  Future<Map<String, Object?>> hqCreateTenantUser({
    required String targetTenantId,
    required String phoneNumber,
    String? displayName,
  }) async {
    final phone = phoneNumber.trim();
    final dn = displayName?.trim();

    if (phone.isEmpty) {
      throw Exception('❌ HQ create tenant user: phoneNumber is required');
    }

    final uri = routes.hqCreateTenantUser(targetTenantId);
    if (kDebugMode) debugPrint('🛰️ $_tag POST $uri');

    final r = await dio.postUri(
      uri,
      data: <String, Object?>{
        'phoneNumber': phone,
        if (dn != null && dn.isNotEmpty) 'displayName': dn,
      },
      options: Options(contentType: Headers.jsonContentType),
    );

    if (!_ok(r)) _bad(r, 'HQ create tenant user');

    return Map<String, Object?>.from(_asMap(r.data));
  }

  /// GET /api/tenants/:slug/auth_users/:uid
  Future<AllUser> hqGetTenantUserById(String targetTenantId, String uid) async {
    final uri = routes.hqGetTenantUserById(targetTenantId, uid);
    if (kDebugMode) debugPrint('🛰️ $_tag GET $uri');

    final r = await dio.getUri(uri);
    if (!_ok(r)) _bad(r, 'HQ get tenant user');

    return _userFromResponse(r);
  }

  /// PATCH /api/tenants/:slug/auth_users/:uid
  ///
  /// IMPORTANT:
  /// - Backend PatchAuthUserSchema supports:
  ///   status, displayName, avatarUrl, stores, type(member|staff), staffRoles[],
  ///   isCompany, companyName, firstName, lastName.
  Future<Map<String, Object?>> hqPatchTenantUser({
    required String targetTenantId,
    required String uid,
    required Map<String, Object?> patch,
  }) async {
    if (patch.isEmpty) {
      throw Exception('❌ HQ patch tenant user: no fields to update');
    }

    final uri = routes.hqPatchTenantUser(targetTenantId, uid);
    if (kDebugMode) debugPrint('🛰️ $_tag PATCH $uri');

    final r = await dio.patchUri(
      uri,
      data: patch, // pass through; allow nullables + empty arrays intentionally
      options: Options(contentType: Headers.jsonContentType),
    );

    if (!_ok(r)) _bad(r, 'HQ patch tenant user');

    return Map<String, Object?>.from(_asMap(r.data));
  }

  /// DELETE /api/tenants/:slug/auth_users/:uid
  Future<void> hqDeleteTenantUser({
    required String targetTenantId,
    required String uid,
  }) async {
    final uri = routes.hqDeleteTenantUser(targetTenantId, uid);
    if (kDebugMode) debugPrint('🛰️ $_tag DELETE $uri');

    final r = await dio.deleteUri(uri);
    final ok = (r.statusCode == 204) || _ok(r);
    if (!ok) _bad(r, 'HQ delete tenant user');

    if (kDebugMode) {
      debugPrint('🗑️ $_tag Removed uid=$uid from tenant=$targetTenantId');
    }
  }
}
