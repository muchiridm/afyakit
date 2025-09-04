import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:afyakit/api/api_client.dart';
import 'package:afyakit/api/api_routes.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';

import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/extensions/user_role_x.dart';

import '../../../shared/types/dtos.dart';

/// Thin HTTP client for tenant-scoped Auth User operations.
/// - Keeps request/response parsing local
/// - Leaves business rules to the Engine/Controller layers
class AuthUserService {
  AuthUserService({required this.client, required this.routes});

  final ApiClient client;
  final ApiRoutes routes;

  Dio get _dio => client.dio;

  // ─────────────────────────────────────────────
  // Consts / Logging
  // ─────────────────────────────────────────────
  static const _json = Headers.jsonContentType;
  static const _tag = '[UserManagerService]';

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  /// Best-effort map coercion from unknown shapes.
  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return Map<String, dynamic>.from(
      jsonDecode(jsonEncode(raw)) as Map<String, dynamic>,
    );
  }

  /// Extracts a list of maps from common response shapes.
  List<Map<String, dynamic>> _asList(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    final m = _asMap(raw);
    final listish = m['results'] ?? m['users'] ?? raw;
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

  // ─────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────

  // CREATE (Invite)
  Future<InviteResult> inviteUser({
    String? email,
    String? phoneNumber,
    UserRole role = UserRole.staff,
    bool forceResend = false,
  }) async {
    final cleanedEmail = email != null ? EmailHelper.normalize(email) : '';
    final cleanedPhone = phoneNumber?.trim() ?? '';
    if (cleanedEmail.isEmpty && cleanedPhone.isEmpty) {
      throw ArgumentError('Either email or phoneNumber must be provided.');
    }

    final payload = <String, Object?>{
      if (cleanedEmail.isNotEmpty) 'email': cleanedEmail,
      if (cleanedPhone.isNotEmpty) 'phoneNumber': cleanedPhone,
      'role': role.wire,
      if (forceResend) 'forceResend': true,
    };

    final r = await _dio.postUri(
      routes.inviteUser(),
      data: payload,
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Invite');

    if (kDebugMode) {
      debugPrint(
        '✅ $_tag Invite sent → ${cleanedEmail.isNotEmpty ? cleanedEmail : cleanedPhone} as ${role.wire}',
      );
    }
    return InviteResult.fromJson(_asMap(r.data));
  }

  // READS
  Future<List<AuthUser>> getAllUsers() async {
    final r = await _dio.getUri(routes.getAllUsers());
    final users = _asList(
      r.data,
    ).map(AuthUser.fromJson).where((u) => u.uid.isNotEmpty).toList();

    if (kDebugMode) {
      debugPrint('✅ $_tag Loaded ${users.length} users');
    }
    return users;
  }

  Future<AuthUser> getUserById(String uid) async {
    final r = await _dio.getUri(routes.getUserById(uid));
    final user = AuthUser.fromJson(
      _asMap(r.data)..putIfAbsent('uid', () => uid),
    );

    if (kDebugMode) {
      debugPrint('✅ $_tag Loaded user: ${user.email} (${user.uid})');
    }
    return user;
  }

  // UPDATE
  Future<void> updateUserFields(String uid, Map<String, Object?> fields) async {
    // prune nulls & empty strings
    final body = Map<String, Object?>.from(fields)
      ..removeWhere((_, v) => v == null || (v is String && v.trim().isEmpty));
    if (body.isEmpty) return;

    final r = await _dio.patchUri(
      routes.updateUser(uid),
      data: body,
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Update user');

    if (kDebugMode) {
      debugPrint('✅ $_tag Updated $uid → $body');
    }
  }

  // DELETE
  Future<void> deleteUser(String uid) async {
    final r = await _dio.deleteUri(routes.deleteUser(uid));
    final ok = (r.statusCode == 204) || ((r.statusCode ?? 0) ~/ 100 == 2);
    if (!ok) _bad(r, 'Delete user');

    if (kDebugMode) {
      debugPrint('🗑️ $_tag Removed tenant membership: $uid');
    }
  }
}
