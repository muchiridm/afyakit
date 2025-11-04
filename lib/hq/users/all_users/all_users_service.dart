// lib/hq/users/all_users/all_users_service.dart
import 'dart:convert';

import 'package:afyakit/api/afyakit/providers.dart'; // afyakitClientProvider
import 'package:afyakit/api/afyakit/routes.dart';
import 'package:afyakit/hq/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/hq/users/all_users/all_user_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// DI: builds service with tenant-scoped routes + Dio from AfyaKitClient
final allUsersServiceProvider = FutureProvider.autoDispose<AllUsersService>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  final client = await ref.watch(afyakitClientProvider.future);
  final routes = AfyaKitRoutes(tenantId);
  return AllUsersService(dio: client.dio, routes: routes);
});

class AllUsersService {
  AllUsersService({required this.dio, required this.routes});

  final Dio dio;
  final AfyaKitRoutes routes;

  // ── helpers ──────────────────────────────────────────────────
  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    // last-resort normalization
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

  // ── Directory (HQ/global users on CORE base) ─────────────────
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

    if (kDebugMode) debugPrint('🛰️ [AllUsersService] GET $uri');
    final r = await dio.getUri(uri);
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'List users');

    if (kDebugMode) {
      debugPrint(
        '🛰️ [AllUsersService] ← ${r.statusCode}  type=${r.data.runtimeType}',
      );
    }

    final items = _asList(r.data);
    if (kDebugMode) {
      debugPrint('✅ [AllUsersService] parsed ${items.length} users');
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
    if (kDebugMode) debugPrint('🛰️ [AllUsersService] GET $uri');

    final r = await dio.getUri(uri);
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Fetch memberships');

    // Accept either:
    //  A) { memberships: { "<tid>": { role, active }, ... } }
    //  B) { "<tid>": { role, active }, ... } (top-level)
    //  C) legacy list: [ { tenantId, role, active }, ... ]  ← (not returned by current BE, but harmless)
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
        };
      });
      return out;
    }

    // (Optional) handle legacy list shape if ever returned
    if (raw is List) {
      for (final e in raw.whereType<Map>()) {
        final v = Map<String, dynamic>.from(e);
        final tid = (v['tenantId'] ?? v['tenant'] ?? '').toString();
        if (tid.isEmpty) continue;
        out[tid] = {'role': v['role'], 'active': v['active'] == true};
      }
    }

    return out;
  }
}
