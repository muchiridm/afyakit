// lib/users/services/auth_user_service.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:afyakit/shared/api/api_client.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:afyakit/users/models/auth_user_model.dart';

class AuthUserService {
  final ApiClient client;
  final ApiRoutes routes;
  AuthUserService({required this.client, required this.routes});

  Dio get _dio => client.dio;
  static const _json = Headers.jsonContentType;

  // Centralized decode helpers (DRY)
  Map<String, dynamic> _decodeMap(dynamic raw, {String? fallbackUid}) {
    final Map<String, dynamic> m = switch (raw) {
      Map data when data['result'] is Map => Map<String, dynamic>.from(
        data['result'] as Map,
      ),
      Map data => Map<String, dynamic>.from(data),
      _ => Map<String, dynamic>.from(jsonDecode(jsonEncode(raw))),
    };
    if (fallbackUid != null &&
        (m['uid'] == null || (m['uid'] as String).isEmpty)) {
      m['uid'] = fallbackUid;
    }
    return m;
  }

  List<Map<String, dynamic>> _decodeList(dynamic raw) {
    final List list = switch (raw) {
      Map data when data['results'] is List => (data['results'] as List),
      List l => l,
      _ => const [],
    };
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // Uniform sender with logging + 2xx check (DRY)
  Future<bool> _send(
    String label,
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      final r = await call();
      final ok = (r.statusCode ?? 0) ~/ 100 == 2;
      if (kDebugMode) {
        if (ok) {
          debugPrint('✅ [AuthUserService] $label OK (${r.statusCode})');
        } else {
          debugPrint(
            '⚠️ [AuthUserService] $label not OK (${r.statusCode}) → ${r.data}',
          );
        }
      }
      return ok;
    } on DioException catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '❌ [AuthUserService] $label failed (code=${e.response?.statusCode}): ${e.message}',
        );
        if (e.response?.data != null) {
          debugPrint('↩︎ body: ${e.response!.data}');
        }
        debugPrintStack(stackTrace: st);
      }
      return false;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('❌ [AuthUserService] $label threw: $e');
        debugPrintStack(stackTrace: st);
      }
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 📩 Invite / Reinvite
  // ─────────────────────────────────────────────────────────────
  Future<void> inviteUser({
    String? email,
    String? phoneNumber,
    String? role, // accepted as-is; engine should normalize
    bool forceResend = false,
  }) async {
    final cleanedEmail = email != null ? EmailHelper.normalize(email) : '';
    final cleanedPhone = phoneNumber?.trim() ?? '';
    if (cleanedEmail.isEmpty && cleanedPhone.isEmpty) {
      throw ArgumentError('❌ Either email or phoneNumber must be provided.');
    }

    final payload = <String, dynamic>{
      if (cleanedEmail.isNotEmpty) 'email': cleanedEmail,
      if (cleanedPhone.isNotEmpty) 'phoneNumber': cleanedPhone,
      if (role != null && role.isNotEmpty) 'role': role,
      if (forceResend) 'forceResend': true,
    };

    final res = await _dio.postUri(routes.inviteUser(), data: payload);
    if ((res.statusCode ?? 0) ~/ 100 != 2) {
      final reason =
          (res.data is Map ? (res.data as Map)['error'] : null) ?? 'Unknown';
      throw Exception('❌ Failed to invite user: $reason');
    }
    if (kDebugMode) {
      debugPrint(
        '✅ [AuthUserService] Invite sent → '
        '${cleanedEmail.isNotEmpty ? cleanedEmail : cleanedPhone}'
        '${role != null && role.isNotEmpty ? ' as $role' : ''}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 🔍 Read (auth_users only)
  // ─────────────────────────────────────────────────────────────
  Future<AuthUser> getUserById(String uid) async {
    final res = await _dio.getUri(routes.getUserById(uid));
    final user = AuthUser.fromJson(_decodeMap(res.data, fallbackUid: uid));
    if (kDebugMode) {
      debugPrint(
        '✅ [AuthUserService] Loaded user: ${user.email} (${user.uid})',
      );
    }
    return user;
  }

  Future<List<AuthUser>> getAllUsers() async {
    final res = await _dio.getUri(routes.getAllUsers());
    final users = _decodeList(
      res.data,
    ).map(AuthUser.fromJson).where((u) => u.uid.isNotEmpty).toList();
    if (kDebugMode) {
      debugPrint('✅ [AuthUserService] Loaded ${users.length} users');
    }
    return users;
  }

  // ─────────────────────────────────────────────────────────────
  // 🗑️ Delete (auth_users)
  // ─────────────────────────────────────────────────────────────
  Future<void> deleteUser(String uid) async {
    final ok = await _send(
      'DELETE user $uid',
      () => _dio.deleteUri(routes.deleteUser(uid)),
    );
    if (!ok) throw Exception('Delete failed');
    if (kDebugMode) debugPrint('🗑️ [AuthUserService] User deleted: $uid');
  }

  // ─────────────────────────────────────────────────────────────
  // ✏️ Update (auth_users only; strategy-based for compatibility)
  // ─────────────────────────────────────────────────────────────
  Future<void> updateFields(String uid, Map<String, dynamic> updates) async {
    final cleaned = _cleanUpdates(updates);
    if (cleaned.isEmpty) {
      throw ArgumentError('❌ No fields provided for update');
    }

    final uriMain = routes.updateUser(uid);

    // Precompute conditional sub-patches
    final hasRole = cleaned.containsKey('role');
    final hasStores = cleaned.containsKey('stores');
    final profileKeys = const [
      'displayName',
      'phoneNumber',
      'avatarUrl',
      'createdAt',
      'status',
      'email',
    ];
    final profilePatch = <String, dynamic>{
      for (final k in profileKeys)
        if (cleaned.containsKey(k)) k: cleaned[k],
    };

    // Define strategies in order (DRY)
    final strategies =
        <
          ({
            String label,
            Future<Response<dynamic>> Function() call,
            bool enabled,
          })
        >[
          (
            label: 'PATCH/plain',
            call: () => _dio.patchUri(
              uriMain,
              data: cleaned,
              options: Options(contentType: _json),
            ),
            enabled: true,
          ),
          (
            label: 'PUT/plain',
            call: () => _dio.putUri(
              uriMain,
              data: cleaned,
              options: Options(contentType: _json),
            ),
            enabled: true,
          ),

          if (hasRole)
            (
              label: 'PATCH/role',
              call: () => _dio.patchUri(
                routes.updateAuthUserRole(uid),
                data: {'role': cleaned['role']},
                options: Options(contentType: _json),
              ),
              enabled: true,
            ),

          if (hasStores)
            (
              label: 'PATCH/stores',
              call: () {
                final stores = (cleaned['stores'] as List)
                    .map((e) => e.toString().trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                return _dio.patchUri(
                  routes.updateAuthUserStores(uid),
                  data: {'stores': stores},
                  options: Options(contentType: _json),
                );
              },
              enabled: true,
            ),

          if (profilePatch.isNotEmpty)
            (
              label: 'PATCH/profile',
              call: () => _dio.patchUri(
                routes.updateAuthUserProfile(uid),
                data: profilePatch,
                options: Options(contentType: _json),
              ),
              enabled: true,
            ),

          // Last resorts
          (
            label: 'PATCH/withUid',
            call: () => _dio.patchUri(
              uriMain,
              data: {'uid': uid, ...cleaned},
              options: Options(contentType: _json),
            ),
            enabled: true,
          ),
          (
            label: 'PATCH/wrapped',
            call: () => _dio.patchUri(
              uriMain,
              data: {'updates': cleaned},
              options: Options(contentType: _json),
            ),
            enabled: true,
          ),
        ];

    // Run until one succeeds
    for (final s in strategies) {
      if (!s.enabled) continue;
      if (await _send(s.label, s.call)) return;
    }

    throw Exception('Update failed');
  }

  // Sugar
  Future<void> setProfile(
    String uid, {
    String? displayName,
    String? phoneNumber,
    String? avatarUrl,
  }) => updateFields(uid, {
    if (displayName != null) 'displayName': displayName.trim(),
    if (phoneNumber != null) 'phoneNumber': phoneNumber.trim(),
    if (avatarUrl != null) 'avatarUrl': avatarUrl.trim(),
  });

  Future<void> setRole(String uid, String role) =>
      updateFields(uid, {'role': role});

  Future<void> setStores(String uid, List<String> stores) =>
      updateFields(uid, {'stores': stores});

  Future<void> activate(String uid) => updateFields(uid, {'status': 'active'});

  Future<void> disable(String uid) => updateFields(uid, {'status': 'disabled'});

  // ── Helpers
  Map<String, dynamic> _cleanUpdates(Map<String, dynamic> raw) {
    final out = <String, dynamic>{};
    for (final e in raw.entries) {
      final v = e.value;
      if (v == null) continue;
      if (v is String) {
        final t = v.trim();
        if (t.isEmpty) continue;
        out[e.key] = t;
      } else {
        out[e.key] = v;
      }
    }
    if (kDebugMode) debugPrint('🧽 [AuthUserService] Cleaned updates → $out');
    return out;
  }
}
