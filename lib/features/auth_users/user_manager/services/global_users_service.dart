import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:afyakit/features/api/api_client.dart';
import 'package:afyakit/features/api/api_routes.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';

import 'package:afyakit/features/auth_users/models/global_user_model.dart';
import 'package:afyakit/features/auth_users/models/super_admim_model.dart';
import 'package:afyakit/features/auth_users/user_manager/extensions/user_role_x.dart';

import 'dtos.dart';

class GlobalUsersService {
  GlobalUsersService({required this.client, required this.routes});
  final ApiClient client;
  final ApiRoutes routes;

  Dio get _dio => client.dio;
  static const _json = Headers.jsonContentType;
  static const _tag = '[GlobalUsersService]';

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

  // ── Superadmins ──────────────────────────────────────────────
  Future<List<SuperAdmin>> listSuperAdmins() async {
    final r = await _dio.getUri(routes.listSuperAdmins());
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'List superadmins');

    final data = _asMap(r.data);
    final list = _asList(data['users'] ?? r.data);
    return list.map(SuperAdmin.fromJson).toList();
  }

  Future<void> setSuperAdmin({required String uid, required bool value}) async {
    final r = await _dio.postUri(
      routes.setSuperAdmin(uid),
      data: {'value': value},
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Set superadmin');
    if (kDebugMode) {
      debugPrint('⭐ $_tag Superadmin=${value ? 'ON' : 'OFF'} → $uid');
    }
  }

  // ── Global directory ─────────────────────────────────────────
  Future<List<GlobalUser>> fetchGlobalUsers({
    String? tenantId,
    String search = '',
    int limit = 50,
  }) async {
    final r = await _dio.getUri(
      routes.listGlobalUsers(tenant: tenantId, search: search, limit: limit),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'List global users');

    final items = _asList(r.data);
    return items.map((m) {
      final id = (m['id'] ?? m['uid'] ?? '').toString();
      return GlobalUser.fromJson(id, Map<String, Object?>.from(m));
    }).toList();
  }

  Future<Map<String, Map<String, Object?>>> fetchUserMemberships(
    String uid,
  ) async {
    final r = await _dio.getUri(routes.fetchUserMemberships(uid));
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Fetch memberships');

    final map = <String, Map<String, Object?>>{};
    final data = _asMap(r.data);
    final items = _asList(data['memberships'] ?? r.data);
    for (final m in items) {
      final tid = (m['tenantId'] ?? m['id'] ?? '').toString();
      map[tid] = {'role': m['role'], 'active': m['active']};
    }
    return map;
  }

  // ── Cross-tenant actions (HQ) ────────────────────────────────
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
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'HQ Invite');

    if (kDebugMode) {
      debugPrint(
        '⭐ $_tag Invited into $targetTenantId as ${role.wire}'
        '${forceResend ? ' (resend)' : ''}',
      );
    }

    return InviteResult.fromJson(_asMap(r.data));
  }

  Future<void> deleteUserForTenant(String targetTenantId, String uid) async {
    final r = await _dio.deleteUri(routes.hqDeleteUser(targetTenantId, uid));
    final ok = (r.statusCode == 204) || ((r.statusCode ?? 0) ~/ 100 == 2);
    if (!ok) _bad(r, 'HQ Delete user');
    if (kDebugMode) {
      debugPrint('🗑️ $_tag Removed $uid from $targetTenantId (HQ)');
    }
  }
}
