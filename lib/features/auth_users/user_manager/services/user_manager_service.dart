import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:afyakit/features/api/api_client.dart';
import 'package:afyakit/features/api/api_routes.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';

import 'package:afyakit/features/auth_users/models/auth_user_model.dart';
import 'package:afyakit/features/auth_users/user_manager/extensions/user_role_x.dart';
import 'package:afyakit/features/auth_users/user_manager/extensions/user_status_x.dart';

import 'dtos.dart';

class UserManagerService {
  UserManagerService({required this.client, required this.routes});
  final ApiClient client;
  final ApiRoutes routes;

  Dio get _dio => client.dio;
  static const _json = Headers.jsonContentType;
  static const _tag = '[UserManagerService]';

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
    final results = m['results'];
    if (results is List) {
      return results
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

  // ── 1) Invite (tenant-scoped) ────────────────────────────────
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

  // ── 2) Reads (tenant-scoped list + single) ───────────────────
  Future<List<AuthUser>> getAllUsers() async {
    final r = await _dio.getUri(routes.getAllUsers());
    final users = _asList(
      r.data,
    ).map(AuthUser.fromJson).where((u) => u.uid.isNotEmpty).toList();
    if (kDebugMode) debugPrint('✅ $_tag Loaded ${users.length} users');
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

  // ── 3) Role ──────────────────────────────────────────────────
  Future<void> assignRole(String uid, UserRole role) async {
    final r = await _dio.patchUri(
      routes.updateAuthUserRole(uid),
      data: {'role': role.wire},
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Assign role');
    if (kDebugMode) debugPrint('✅ $_tag Role updated → $uid : ${role.wire}');
  }

  // ── 4) Stores ────────────────────────────────────────────────
  Future<void> setStores(String uid, List<String> stores) async {
    final payload = {
      'stores': stores.map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
    };
    final r = await _dio.patchUri(
      routes.updateAuthUserStores(uid),
      data: payload,
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Set stores');
    if (kDebugMode) {
      debugPrint('✅ $_tag Stores updated → $uid : ${payload['stores']}');
    }
  }

  // ── 5) Status ────────────────────────────────────────────────
  Future<void> setStatus(String uid, UserStatus status) async {
    final r = await _dio.patchUri(
      routes.updateUser(uid),
      data: {'status': status.wire},
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Set status');
    if (kDebugMode) {
      debugPrint('✅ $_tag Status updated → $uid : ${status.wire}');
    }
  }

  Future<void> activateUser(String uid) => setStatus(uid, UserStatus.active);
  Future<void> disableUser(String uid) => setStatus(uid, UserStatus.disabled);

  // ── 6) Profile ───────────────────────────────────────────────
  Future<void> updateProfile(String uid, UpdateProfileRequest req) async {
    final body = req.toJson();
    if (body.isEmpty) return;
    final r = await _dio.patchUri(
      routes.updateAuthUserProfile(uid),
      data: body,
      options: Options(contentType: _json),
    );
    if ((r.statusCode ?? 0) ~/ 100 != 2) _bad(r, 'Update profile');
    if (kDebugMode) debugPrint('✅ $_tag Profile updated → $uid : $body');
  }

  // ── 7) Delete (tenant membership) ────────────────────────────
  Future<void> deleteUser(String uid) async {
    final r = await _dio.deleteUri(routes.deleteUser(uid));
    final ok = (r.statusCode == 204) || ((r.statusCode ?? 0) ~/ 100 == 2);
    if (!ok) _bad(r, 'Delete user');
    if (kDebugMode) debugPrint('🗑️ $_tag User removed from tenant: $uid');
  }
}
