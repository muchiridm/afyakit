// lib/hq/users/super_admins/super_admins_service.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:afyakit/core/api/afyakit/routes.dart';

import 'package:afyakit/modules/hq/users/super_admins/super_admin_model.dart';
import 'package:afyakit/core/auth_user/models/auth_user_model.dart';

/// Network layer for HQ superadmin features + cross-tenant user ops.
///
/// Notes:
/// - `GET /api/superadmins` can return a top-level JSON array or a wrapped shape.
/// - All methods accept any 2xx; deletes also accept 204.
class SuperAdminsService {
  SuperAdminsService({required this.dio, required this.routes});

  final Dio dio;
  final AfyaKitRoutes routes;

  static const _json = Headers.jsonContentType;
  static const _tag = '[SuperAdminsService]';

  // ────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────

  /// Accepts:
  ///  - top-level array: `[ {...}, {...} ]`
  ///  - wrapped: `{ users: [...] }` / `{ results: [...] }` / `{ items: [...] }` / `{ data: [...] }`
  ///  - map-of-objects keyed by id
  List<Map<String, dynamic>> _asList(Object? raw) {
    if (raw == null) return const <Map<String, dynamic>>[];

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);

      for (final c in [m['users'], m['results'], m['items'], m['data']]) {
        if (c is List) {
          return c
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

  Never _bad(Response r, String op) {
    final status = r.statusCode ?? 0;
    final data = r.data;
    String? reason;
    if (data is Map && data['error'] != null) {
      reason = data['error'].toString();
    }
    throw Exception(
      '❌ $op failed ($status)${reason != null ? ': $reason' : ''}',
    );
  }

  bool _ok(Response r) => ((r.statusCode ?? 0) ~/ 100) == 2;

  // ────────────────────────────────────────────────────────────
  // Superadmins
  // ────────────────────────────────────────────────────────────

  /// GET /api/superadmins  →  returns List<SuperAdmin>
  Future<List<SuperAdmin>> listSuperAdmins() async {
    final uri = routes.listSuperAdmins();
    if (kDebugMode) debugPrint('🛰️ $_tag GET $uri');

    final r = await dio.getUri(uri);

    if (kDebugMode) {
      debugPrint('🛰️ $_tag ← ${r.statusCode}  type=${r.data.runtimeType}');
      debugPrint('🛰️ $_tag body preview: ${_previewBody(r.data)}');
    }
    if (!_ok(r)) _bad(r, 'List superadmins');

    List<Map<String, dynamic>> items = const [];
    try {
      items = _asList(r.data);
    } catch (e, st) {
      if (kDebugMode) debugPrint('🧨 $_tag parse error: $e\n$st');
    }

    if (items.isEmpty && r.data is Map) {
      final m = Map<String, dynamic>.from(r.data as Map);
      final altKey = [
        'superadmins',
        'users',
        'results',
        'items',
        'data',
      ].firstWhere((k) => m[k] is List, orElse: () => '');
      if (altKey.isNotEmpty) {
        items = (m[altKey] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (m.values.isNotEmpty && m.values.every((v) => v is Map)) {
        items = m.values
            .cast<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    if (kDebugMode) debugPrint('✅ $_tag parsed ${items.length} superadmins');

    final out = items.map((raw) {
      final map = Map<String, dynamic>.from(raw);
      map['uid'] = (map['uid'] ?? map['id'] ?? '').toString();
      return SuperAdmin.fromJson(map);
    }).toList();

    if (kDebugMode) {
      final who = out.map((s) => s.phoneNumber ?? s.email ?? s.uid).join(', ');
      debugPrint('👥 $_tag returning ${out.length}: [$who]');
    }
    return out;
  }

  String _previewBody(Object? data) {
    try {
      final s = data is String ? data : jsonEncode(data);
      return s.length > 600 ? '${s.substring(0, 600)}… (${s.length} chars)' : s;
    } catch (_) {
      return data.toString();
    }
  }

  /// POST /api/superadmins/:uid  { value: bool }
  Future<void> setSuperAdmin({required String uid, required bool value}) async {
    final r = await dio.postUri(
      routes.setSuperAdmin(uid),
      data: {'value': value},
      options: Options(contentType: _json),
    );
    if (!_ok(r)) _bad(r, 'Set superadmin');

    if (kDebugMode) {
      debugPrint('⭐ $_tag Superadmin=${value ? 'ON' : 'OFF'} → $uid');
    }
  }

  // ────────────────────────────────────────────────────────────
  // Cross-tenant (HQ) user actions
  // ────────────────────────────────────────────────────────────

  /// GET /api/tenants/:tenantId/auth_users  → List<AuthUser>
  Future<List<AuthUser>> listUsersForTenant({
    required String tenantId,
    String? search,
    int limit = 50,
  }) async {
    final r = await dio.getUri(
      routes.hqListTenantUsers(tenantId, search: search, limit: limit),
    );
    if (!_ok(r)) _bad(r, 'List tenant users');

    final items = _asList(r.data);
    final users = items
        .map<Map<String, dynamic>>((m) {
          final map = Map<String, dynamic>.from(m);
          final uid = (map['uid'] ?? map['id'] ?? '').toString().trim();
          if (uid.isEmpty) return const {};
          map['uid'] = uid;
          return map;
        })
        .where((m) => (m['uid'] ?? '').toString().isNotEmpty)
        .map<AuthUser?>((m) {
          try {
            return AuthUser.fromJson(m);
          } catch (e, st) {
            if (kDebugMode) debugPrint('Skipping bad user row: $e\n$st');
            return null;
          }
        })
        .whereType<AuthUser>()
        .toList();

    if (kDebugMode) {
      debugPrint('✅ $_tag Loaded ${users.length} users for tenant=$tenantId');
    }
    return users;
  }

  /// DELETE /api/tenants/:tenantId/auth_users/:uid
  Future<void> deleteUserForTenant(String targetTenantId, String uid) async {
    final r = await dio.deleteUri(routes.hqDeleteUser(targetTenantId, uid));
    final ok = (r.statusCode == 204) || _ok(r);
    if (!ok) _bad(r, 'Delete user');

    if (kDebugMode) {
      debugPrint('🗑️ $_tag Removed $uid from $targetTenantId (HQ)');
    }
  }
}
