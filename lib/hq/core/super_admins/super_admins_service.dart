// lib/hq/users/super_admins/super_admin_service.dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:afyakit/api/api_client.dart';
import 'package:afyakit/api/api_routes.dart';

import 'package:afyakit/hq/core/super_admins/super_admin_model.dart';
import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/extensions/user_role_x.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:afyakit/shared/types/dtos.dart';

/// Network layer for HQ superadmin features + cross-tenant user ops.
///
/// Notes:
/// - `GET /api/superadmins` returns a **top-level JSON array**.
/// - All methods accept 2xx; deletes also accept 204.
class SuperAdminsService {
  SuperAdminsService({required this.client, required this.routes});

  final ApiClient client;
  final ApiRoutes routes;

  Dio get _dio => client.dio;

  static const _json = Headers.jsonContentType;
  static const _tag = '[SuperAdminsService]';

  // ────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    // Fallback: only used by callers that expect a map.
    try {
      final enc = jsonEncode(raw);
      final dec = jsonDecode(enc);
      if (dec is Map) return Map<String, dynamic>.from(dec);
    } catch (_) {}
    return const <String, dynamic>{};
  }

  /// Accepts:
  ///  - top-level array: `[ {...}, {...} ]`
  ///  - wrapped: `{ users: [...] }` or `{ results: [...] }`
  List<Map<String, dynamic>> _asList(Object? raw) {
    if (raw == null) return const <Map<String, dynamic>>[];

    // Top-level array
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    // Top-level map that wraps the list or is a map-of-objects
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);

      // Common wrapper keys
      final candidates = [m['users'], m['results'], m['items'], m['data']];
      for (final c in candidates) {
        if (c is List) {
          return c
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      // Map-of-objects keyed by id -> flatten values
      final values = m.values.toList();
      if (values.isNotEmpty && values.every((v) => v is Map)) {
        return values
            .cast<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    // Optional: if you sometimes get a JSON string, uncomment:
    // if (raw is String) {
    //   try { return _asList(jsonDecode(raw)); } catch (_) {}
    // }

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

    final r = await _dio.getUri(uri);

    if (kDebugMode) {
      debugPrint('🛰️ $_tag ← ${r.statusCode}  type=${r.data.runtimeType}');
      debugPrint('🛰️ $_tag body preview: ${_previewBody(r.data)}');
    }
    if (!_ok(r)) _bad(r, 'List superadmins');

    // Try the normal parse first
    List<Map<String, dynamic>> items = const [];
    try {
      items = _asList(r.data);
    } catch (e, st) {
      if (kDebugMode) debugPrint('🧨 $_tag parse error: $e\n$st');
    }

    // Fallbacks for odd shapes: {superadmins:[...]}, {items:[...]}, map-of-objects
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
        final list = (m[altKey] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        items = list;
      } else if (m.values.isNotEmpty && m.values.every((v) => v is Map)) {
        // map-of-objects keyed by uid
        items = m.values
            .cast<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    if (kDebugMode) debugPrint('✅ $_tag parsed ${items.length} superadmins');

    final out = items.map((raw) {
      final map = Map<String, dynamic>.from(raw);
      // normalize ID field just in case
      map['uid'] = (map['uid'] ?? map['id'] ?? '').toString();
      return SuperAdmin.fromJson(map);
    }).toList();

    if (kDebugMode) {
      final who = out.map((s) => s.email ?? s.uid).join(', ');
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
    final r = await _dio.postUri(
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
    final r = await _dio.getUri(
      routes.hqListTenantUsers(tenantId, search: search, limit: limit),
    );
    if (!_ok(r)) _bad(r, 'List tenant users');

    // Ensure we have a typed list of maps, then map to AuthUser
    final items = _asList(r.data); // List<Map<String,dynamic>>
    final users = items
        .map<Map<String, dynamic>>((m) {
          final map = Map<String, dynamic>.from(m);
          final uid = (map['uid'] ?? map['id'] ?? '').toString().trim();
          if (uid.isEmpty) return const {}; // drop later
          map['uid'] = uid;
          return map;
        })
        .where((m) => (m['uid'] ?? '').toString().isNotEmpty)
        .map<AuthUser?>((m) {
          try {
            return AuthUser.fromJson(m);
          } catch (e, st) {
            if (kDebugMode) debugPrint('Skipping bad user row: $e\n$st');
            return null; // ✅ return nullable
          }
        })
        .whereType<AuthUser>() // ✅ strip nulls
        .toList();

    if (kDebugMode) {
      debugPrint('✅ $_tag Loaded ${users.length} users for tenant=$tenantId');
    }
    return users;
  }

  /// POST /api/tenants/:tenantId/auth_users/invite
  Future<InviteResult> inviteUserForTenant({
    required String targetTenantId,
    String? email,
    String? phoneNumber,
    UserRole role = UserRole.staff,
    String? brandBaseUrl,
    bool forceResend = false,
  }) async {
    final cleanedEmail = (email ?? '').trim();
    final cleanedPhone = (phoneNumber ?? '').trim();
    if (cleanedEmail.isEmpty && cleanedPhone.isEmpty) {
      throw ArgumentError('Either email or phoneNumber must be provided.');
    }

    final payload = <String, Object?>{
      if (cleanedEmail.isNotEmpty) 'email': EmailHelper.normalize(cleanedEmail),
      if (cleanedPhone.isNotEmpty) 'phoneNumber': cleanedPhone,
      'role': role.wire,
      if ((brandBaseUrl ?? '').trim().isNotEmpty)
        'brandBaseUrl': brandBaseUrl!.trim(),
      if (forceResend) 'forceResend': true,
    };

    final r = await _dio.postUri(
      routes.hqInviteUser(targetTenantId),
      data: payload,
      options: Options(contentType: _json),
    );
    if (!_ok(r)) _bad(r, 'Invite user');

    if (kDebugMode) {
      debugPrint(
        '⭐ $_tag Invited into $targetTenantId as ${role.wire}'
        '${forceResend ? ' (resend)' : ''}',
      );
    }

    return InviteResult.fromJson(_asMap(r.data));
  }

  /// DELETE /api/tenants/:tenantId/auth_users/:uid
  Future<void> deleteUserForTenant(String targetTenantId, String uid) async {
    final r = await _dio.deleteUri(routes.hqDeleteUser(targetTenantId, uid));
    final ok = (r.statusCode == 204) || _ok(r);
    if (!ok) _bad(r, 'Delete user');

    if (kDebugMode) {
      debugPrint('🗑️ $_tag Removed $uid from $targetTenantId (HQ)');
    }
  }
}
