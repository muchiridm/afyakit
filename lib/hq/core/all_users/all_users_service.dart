import 'dart:convert';
import 'package:afyakit/hq/core/all_users/all_user_model.dart';
import 'package:dio/dio.dart';

import 'package:afyakit/api/api_client.dart';
import 'package:afyakit/api/api_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final allUsersServiceProvider = FutureProvider.autoDispose<AllUsersService>((
  ref,
) async {
  final client = await ref.watch(apiClientProvider.future);
  final routes = ref.watch(apiRouteProvider);
  return AllUsersService(client: client, routes: routes);
});

class AllUsersService {
  AllUsersService({required this.client, required this.routes});

  final ApiClient client;
  final ApiRoutes routes;

  Dio get _dio => client.dio;

  // ── helpers ──────────────────────────────────────────────────
  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return Map<String, dynamic>.from(
      jsonDecode(jsonEncode(raw)) as Map<String, dynamic>,
    );
  }

  List<Map<String, dynamic>> _asList(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
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

  Never _bad(Response r, String op) {
    final reason = r.data is Map ? (r.data as Map)['error'] : null;
    throw Exception('❌ $op failed (${r.statusCode}): ${reason ?? 'Unknown'}');
  }

  // ── Directory (formerly “global users”) ──────────────────────
  Future<List<AllUser>> fetchAllUsers({
    String? tenantId,
    String search = '',
    int limit = 50,
  }) async {
    final q = search.trim().toLowerCase();
    final uri = routes.listGlobalUsers(
      tenant: tenantId,
      search: q,
      limit: limit,
    );
    debugPrint('🛰️ [AllUsersService] GET $uri');
    final r = await _dio.getUri(uri);

    final ok = ((r.statusCode ?? 0) ~/ 100) == 2;
    if (!ok) _bad(r, 'List users');

    debugPrint(
      '🛰️ [AllUsersService] ← ${r.statusCode}  type=${r.data.runtimeType}',
    );
    final items = _asList(r.data);
    debugPrint('✅ [AllUsersService] parsed ${items.length} users');

    final out = items.map((m) {
      final id = (m['id'] ?? m['uid'] ?? '').toString();
      return AllUser.fromJson(id, Map<String, Object?>.from(m));
    }).toList();

    debugPrint('👥 [AllUsersService] returning ${out.length}');
    return out;
  }

  Future<Map<String, Map<String, Object?>>> fetchUserMemberships(
    String uid,
  ) async {
    final uri = routes.fetchUserMemberships(uid);
    debugPrint('🛰️ [AllUsersService] GET $uri');
    final r = await _dio.getUri(uri);

    final ok = ((r.statusCode ?? 0) ~/ 100) == 2;
    if (!ok) _bad(r, 'Fetch memberships');

    // Accept either:
    // A) { memberships: { "<tid>": { role, active }, ... } }
    // B) { "<tid>": { role, active }, ... } (top-level)
    // C) legacy list: [ { tenantId, role, active }, ... ]
    final data = _asMap(r.data);
    final raw = data.containsKey('memberships') ? data['memberships'] : r.data;

    final out = <String, Map<String, Object?>>{};

    // Map-of-objects: { "<tid>": {...} }
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      m.forEach((tid, val) {
        final v = _asMap(val);
        out[tid.toString()] = {
          'role': v['role'],
          'active': v['active'] == true,
        };
      });
      return out;
    }

    return out;
  }
}
