// lib/hq/users/super_admins/super_admins_service.dart

import 'dart:convert';

import 'package:afyakit/features/hq/users/super_admins/super_admin_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:afyakit/core/api/afyakit/routes.dart';
import 'package:afyakit/core/auth_user/models/auth_user_model.dart';

/// Network layer for HQ superadmin features + cross-tenant user ops.
///
/// Notes:
/// - `GET /api/superadmins` may return:
///     - top-level array: `[ {...}, {...} ]`
///     - wrapped: `{ users: [...] }` / `{ results: [...] }` / `{ items: [...] }` / `{ data: [...] }`
///     - map-of-objects keyed by id
/// - All methods accept any 2xx; deletes also accept 204.
class SuperAdminsService {
  SuperAdminsService({required this.dio, required this.routes});

  final Dio dio;
  final AfyaKitRoutes routes;

  static const _json = Headers.jsonContentType;
  static const _tag = '[SuperAdminsService]';

  // ────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────

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
    }

    throw Exception(
      '❌ $op failed ($status)${reason != null ? ': $reason' : ''}',
    );
  }

  String _previewBody(Object? data) {
    try {
      final s = data is String ? data : jsonEncode(data);
      return s.length > 600 ? '${s.substring(0, 600)}… (${s.length} chars)' : s;
    } catch (_) {
      return data.toString();
    }
  }

  /// Normalize unknown API shapes into `List<Map<String, dynamic>>`.
  List<Map<String, dynamic>> _extractList(Object? raw) {
    if (raw == null) return const <Map<String, dynamic>>[];

    // 1) top-level list
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    // 2) wrapped map
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);

      // common wrappers
      for (final key in const [
        'superadmins',
        'users',
        'results',
        'items',
        'data',
      ]) {
        final v = m[key];
        if (v is List) {
          return v
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      // map-of-objects keyed by id
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

  static String _normUid(Object? v) {
    final s = v?.toString().trim();
    return (s == null) ? '' : s;
  }

  // ────────────────────────────────────────────
  // Superadmins
  // ────────────────────────────────────────────

  /// GET /api/superadmins  → List<SuperAdmin>
  Future<List<SuperAdmin>> listSuperAdmins() async {
    final uri = routes.listSuperAdmins();
    if (kDebugMode) debugPrint('🛰️ $_tag GET $uri');

    final r = await dio.getUri(uri);

    if (kDebugMode) {
      debugPrint('🛰️ $_tag ← ${r.statusCode}  type=${r.data.runtimeType}');
      debugPrint('🛰️ $_tag body preview: ${_previewBody(r.data)}');
    }

    if (!_ok(r)) _bad(r, 'List superadmins');

    final items = _extractList(r.data);

    final out = <SuperAdmin>[];
    for (final raw in items) {
      final m = Map<String, dynamic>.from(raw);

      // ensure uid exists
      final uid = _normUid(m['uid'] ?? m['id']);
      if (uid.isEmpty) continue;

      m['uid'] = uid;
      out.add(SuperAdmin.fromJson(m));
    }

    if (kDebugMode) {
      final who = out.map((s) => s.phoneNumber ?? s.email ?? s.uid).join(', ');
      debugPrint('✅ $_tag parsed ${out.length} superadmins: [$who]');
    }

    return out;
  }

  /// POST /api/superadmins/:uid  { value: bool }
  Future<void> setSuperAdmin({required String uid, required bool value}) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'uid must not be empty');
    }

    final r = await dio.postUri(
      routes.setSuperAdmin(cleanUid),
      data: {'value': value},
      options: Options(contentType: _json),
    );

    if (!_ok(r)) _bad(r, 'Set superadmin');

    if (kDebugMode) {
      debugPrint('⭐ $_tag Superadmin=${value ? 'ON' : 'OFF'} → $cleanUid');
    }
  }

  // ────────────────────────────────────────────
  // Cross-tenant (HQ) user actions
  // ────────────────────────────────────────────

  /// GET /api/tenants/:tenantId/auth_users  → List<AuthUser>
  Future<List<AuthUser>> listUsersForTenant({
    required String tenantId,
    String? search,
    int limit = 50,
  }) async {
    final t = tenantId.trim();
    if (t.isEmpty) {
      throw ArgumentError.value(
        tenantId,
        'tenantId',
        'tenantId must not be empty',
      );
    }

    final r = await dio.getUri(
      routes.hqListTenantUsers(t, search: search, limit: limit),
    );

    if (!_ok(r)) _bad(r, 'List tenant users');

    final items = _extractList(r.data);

    final users = <AuthUser>[];
    for (final raw in items) {
      final m = Map<String, dynamic>.from(raw);

      final uid = _normUid(m['uid'] ?? m['id']);
      if (uid.isEmpty) continue;
      m['uid'] = uid;

      try {
        users.add(AuthUser.fromJson(m));
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('🧨 $_tag skipping bad user row uid=$uid: $e\n$st');
        }
      }
    }

    if (kDebugMode) {
      debugPrint('✅ $_tag Loaded ${users.length} users for tenant=$t');
    }

    return users;
  }

  /// DELETE /api/tenants/:tenantId/auth_users/:uid
  Future<void> deleteUserForTenant(String targetTenantId, String uid) async {
    final t = targetTenantId.trim();
    final u = uid.trim();
    if (t.isEmpty) {
      throw ArgumentError.value(
        targetTenantId,
        'targetTenantId',
        'targetTenantId must not be empty',
      );
    }
    if (u.isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'uid must not be empty');
    }

    final r = await dio.deleteUri(routes.hqDeleteUser(t, u));

    final ok = (r.statusCode == 204) || _ok(r);
    if (!ok) _bad(r, 'Delete user');

    if (kDebugMode) {
      debugPrint('🗑️ $_tag Removed $u from $t (HQ)');
    }
  }
}
