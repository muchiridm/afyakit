import 'dart:convert';

import 'package:afyakit/core/api/afyakit/providers.dart'; // afyakitClientProvider
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/core/app_hq/users/all_users/all_user_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// DI: builds service with tenant-scoped routes + Dio from AfyaKitClient.
final allUsersServiceProvider = FutureProvider.autoDispose<AllUsersService>((
  ref,
) async {
  final tenantId = ref.watch(tenantSlugProvider);
  final client = await ref.watch(afyakitClientProvider.future);
  final routes = AfyaKitRoutes(tenantId);
  return AllUsersService(dio: client.dio, routes: routes);
});

class AllUsersService {
  AllUsersService({required this.dio, required this.routes});

  final Dio dio;
  final AfyaKitRoutes routes;

  static const _tag = '[AllUsersService]';

  // ─────────────────────────────────────────────────────────────
  // Helpers: normalize arbitrary JSON payloads
  // ─────────────────────────────────────────────────────────────

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    final enc = jsonEncode(raw);
    final dec = jsonDecode(enc);
    return Map<String, dynamic>.from(dec as Map);
  }

  List<Map<String, dynamic>> _asList(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    // Accept envelopes like: { users: [...] } or { results: [...] }
    final m = _asMap(raw);
    final listish = m['users'] ?? m['results'] ?? raw;

    if (listish is List) {
      return listish
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return const [];
  }

  bool _ok(Response r) => ((r.statusCode ?? 0) ~/ 100) == 2;

  Never _bad(Response r, String op) {
    final reason = r.data is Map ? (r.data as Map)['error'] : r.statusMessage;
    throw Exception('❌ $op failed (${r.statusCode}): ${reason ?? 'Unknown'}');
  }

  AllUser _userFromResponse(Response r) {
    final map = _asMap(r.data);
    final id = (map['id'] ?? map['uid'] ?? '').toString();
    return AllUser.fromJson(id, Map<String, Object?>.from(map));
  }

  // ─────────────────────────────────────────────────────────────
  // Directory (HQ/global users on CORE base)
  // ─────────────────────────────────────────────────────────────

  Future<List<AllUser>> fetchAllUsers({
    String? tenantId,
    String search = '',
    int limit = 50,
  }) async {
    final q = search.trim();

    final uri = routes.listGlobalUsers(
      tenant: (tenantId != null && tenantId.isNotEmpty) ? tenantId : null,
      search: q.isEmpty ? null : q,
      limit: limit,
    );

    if (kDebugMode) debugPrint('🛰️ $_tag GET $uri');
    final r = await dio.getUri(uri);

    if (!_ok(r)) _bad(r, 'List users');

    if (kDebugMode) {
      debugPrint('🛰️ $_tag ← ${r.statusCode} type=${r.data.runtimeType}');
    }

    final items = _asList(r.data);

    if (kDebugMode) {
      debugPrint('✅ $_tag parsed ${items.length} users');
    }

    return items.map((m) {
      final id = (m['id'] ?? m['uid'] ?? '').toString();
      return AllUser.fromJson(id, Map<String, Object?>.from(m));
    }).toList();
  }

  Future<Map<String, Map<String, Object?>>> fetchUserMemberships(
    String uid,
  ) async {
    final uri = routes.fetchUserMemberships(uid);
    if (kDebugMode) debugPrint('🛰️ $_tag GET $uri');

    final r = await dio.getUri(uri);
    if (!_ok(r)) _bad(r, 'Fetch memberships');

    // Accept:
    //  A) { memberships: [ { tenantId, role, active, email? }, ... ] }
    //  B) { memberships: { "<tid>": { role, active, email? }, ... } }
    //  C) { "<tid>": { role, active, email? }, ... } (top-level)
    //  D) legacy list: [ { tenantId, role, active, email? }, ... ]
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
  // Global user CRUD (HQ / directory + Firebase Auth)
  // ─────────────────────────────────────────────────────────────

  Future<AllUser> createGlobalUser({
    required String phoneNumber,
    String? displayName,
  }) async {
    final uri = routes.createGlobalUser();
    if (kDebugMode) debugPrint('🛰️ $_tag POST $uri');

    final body = <String, dynamic>{
      'phoneNumber': phoneNumber,
      if (displayName != null && displayName.trim().isNotEmpty)
        'displayName': displayName.trim(),
    };

    final r = await dio.postUri(
      uri,
      data: body,
      options: Options(contentType: Headers.jsonContentType),
    );

    if (!_ok(r)) _bad(r, 'Create global user');
    final user = _userFromResponse(r);

    if (kDebugMode) {
      debugPrint(
        '✅ $_tag Created user ${user.id} (${user.phoneNumber ?? '-'})',
      );
    }

    return user;
  }

  Future<AllUser> updateGlobalUser({
    required String uid,
    String? phoneNumber,
    String? displayName,
    bool? disabled,
  }) async {
    final uri = routes.updateGlobalUser(uid);
    if (kDebugMode) debugPrint('🛰️ $_tag PATCH $uri');

    final body = <String, dynamic>{};
    if (phoneNumber != null) body['phoneNumber'] = phoneNumber;
    if (displayName != null) body['displayName'] = displayName;
    if (disabled != null) body['disabled'] = disabled;

    if (body.isEmpty) {
      throw Exception('❌ Update global user: no fields to update');
    }

    final r = await dio.patchUri(
      uri,
      data: body,
      options: Options(contentType: Headers.jsonContentType),
    );

    if (!_ok(r)) _bad(r, 'Update global user');
    final user = _userFromResponse(r);

    if (kDebugMode) {
      debugPrint('✅ $_tag Updated user ${user.id} (disabled=${user.disabled})');
    }

    return user;
  }

  Future<void> deleteGlobalUser(String uid) async {
    final uri = routes.deleteGlobalUser(uid);
    if (kDebugMode) debugPrint('🛰️ $_tag DELETE $uri');

    final r = await dio.deleteUri(uri);
    final ok = (r.statusCode == 204) || _ok(r);
    if (!ok) _bad(r, 'Delete global user');

    if (kDebugMode) {
      debugPrint('🗑️ $_tag Deleted global user $uid');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Membership mutations (super-admin, HQ)
  // ─────────────────────────────────────────────────────────────

  Future<void> upsertUserMembership({
    required String uid,
    required String tenantId,
    required String role,
    required bool active,
    String? email,
  }) async {
    final uri = routes.hqUpsertUserMembership(tenantId, uid);
    if (kDebugMode) debugPrint('🛰️ $_tag PUT $uri');

    final body = <String, dynamic>{
      'role': role,
      'active': active,
      if (email != null) 'email': email,
    };

    final r = await dio.putUri(
      uri,
      data: body,
      options: Options(contentType: Headers.jsonContentType),
    );

    if (!_ok(r)) _bad(r, 'Upsert membership');
  }

  Future<void> deleteUserMembership({
    required String uid,
    required String tenantId,
  }) async {
    final uri = routes.hqDeleteUser(tenantId, uid);
    if (kDebugMode) debugPrint('🛰️ $_tag DELETE $uri');

    final r = await dio.deleteUri(uri);
    final ok = (r.statusCode == 204) || _ok(r);
    if (!ok) _bad(r, 'Delete membership');

    if (kDebugMode) {
      debugPrint('🗑️ $_tag Removed $uid from tenant=$tenantId');
    }
  }
}
