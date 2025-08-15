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

  // ─────────────────────────────────────────────────────────────
  // 📩 Invite / Reinvite
  // ─────────────────────────────────────────────────────────────
  Future<void> inviteUser({
    String? email,
    String? phoneNumber,
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
      if (forceResend) 'forceResend': true,
    };

    final res = await client.dio.postUri(routes.inviteUser(), data: payload);
    if ((res.statusCode ?? 0) ~/ 100 != 2) {
      final reason = (res.data is Map ? res.data['error'] : null) ?? 'Unknown';
      throw Exception('❌ Failed to invite user: $reason');
    }
    debugPrint(
      '✅ [AuthUserService] Invite sent → '
      '${cleanedEmail.isNotEmpty ? cleanedEmail : cleanedPhone}',
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 🔍 Read (auth_users only)
  // ─────────────────────────────────────────────────────────────
  Future<AuthUser> getUserById(String uid) async {
    final res = await client.dio.getUri(routes.getUserById(uid));
    final raw = res.data;
    final Map<String, dynamic> map = switch (raw) {
      Map m when m['result'] is Map => Map<String, dynamic>.from(m['result']),
      Map m => Map<String, dynamic>.from(m),
      _ => Map<String, dynamic>.from(jsonDecode(jsonEncode(raw))),
    }..putIfAbsent('uid', () => uid);
    final user = AuthUser.fromJson(map);
    debugPrint('✅ [AuthUserService] Loaded user: ${user.email} (${user.uid})');
    return user;
  }

  Future<List<AuthUser>> getAllUsers() async {
    final res = await client.dio.getUri(routes.getAllUsers());
    final raw = res.data;

    final List list = switch (raw) {
      Map m when m['results'] is List => (m['results'] as List),
      List l => l,
      _ => const [],
    };

    final users = list
        .whereType<Map>()
        .map((m) => AuthUser.fromJson(Map<String, dynamic>.from(m)))
        .where((u) => u.uid.isNotEmpty)
        .toList();

    debugPrint('✅ [AuthUserService] Loaded ${users.length} users');
    return users;
  }

  // ─────────────────────────────────────────────────────────────
  // 🗑️ Delete (auth_users)
  // ─────────────────────────────────────────────────────────────
  Future<void> deleteUser(String uid) async {
    final res = await client.dio.deleteUri(routes.deleteUser(uid));
    if ((res.statusCode ?? 0) ~/ 100 != 2) {
      throw Exception('Delete failed (${res.statusCode})');
    }
    debugPrint('🗑️ [AuthUserService] User deleted: $uid');
  }

  // ─────────────────────────────────────────────────────────────
  // ✏️ Update (auth_users only; multi-strategy for compatibility)
  // ─────────────────────────────────────────────────────────────
  Future<void> updateFields(String uid, Map<String, dynamic> updates) async {
    final cleaned = _cleanUpdates(updates);
    if (cleaned.isEmpty) {
      throw ArgumentError('❌ No fields provided for update');
    }

    final uriMain = routes.updateUser(uid);
    final contentType = Headers.jsonContentType;

    Future<bool> tryCall(String label, Future<Response> Function() call) async {
      try {
        debugPrint('🌍 [AuthUserService] $label → $uriMain | payload=$cleaned');
        final r = await call();
        final ok = (r.statusCode ?? 0) ~/ 100 == 2;
        debugPrint(
          ok
              ? '✅ [AuthUserService] $label OK (${r.statusCode})'
              : '⚠️ [AuthUserService] $label not OK (${r.statusCode}) → ${r.data}',
        );
        return ok;
      } on DioException catch (e, st) {
        final code = e.response?.statusCode;
        debugPrint(
          '❌ [AuthUserService] $label failed (code=$code): ${e.message}',
        );
        if (e.response?.data != null)
          debugPrint('↩︎ body: ${e.response!.data}');
        debugPrintStack(stackTrace: st);
        return false;
      } catch (e, st) {
        debugPrint('❌ [AuthUserService] $label threw: $e');
        debugPrintStack(stackTrace: st);
        return false;
      }
    }

    // 1) Preferred: PATCH auth_users/:id with plain fields
    if (await tryCall(
      'PATCH/plain',
      () => client.dio.patchUri(
        uriMain,
        data: cleaned,
        options: Options(contentType: contentType),
      ),
    )) {
      return;
    }

    // 2) Fallback: PUT auth_users/:id with plain fields
    if (await tryCall(
      'PUT/plain',
      () => client.dio.putUri(
        uriMain,
        data: cleaned,
        options: Options(contentType: contentType),
      ),
    )) {
      return;
    }

    // 3) Field-specific subresources under auth_users (role / stores / profile)
    // This keeps FE auth-only while staying compatible with older deploys.
    bool any = false;

    if (cleaned.containsKey('role')) {
      final roleUri = routes.updateAuthUserRole(uid);
      final ok = await tryCall(
        'PATCH/role',
        () => client.dio.patchUri(
          roleUri,
          data: {'role': cleaned['role']},
          options: Options(contentType: contentType),
        ),
      );
      any = any || ok;
    }

    if (cleaned.containsKey('stores')) {
      final storesUri = routes.updateAuthUserStores(uid);
      final stores = (cleaned['stores'] as List)
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final ok = await tryCall(
        'PATCH/stores',
        () => client.dio.patchUri(
          storesUri,
          data: {'stores': stores},
          options: Options(contentType: contentType),
        ),
      );
      any = any || ok;
    }

    final profilePatch = <String, dynamic>{};
    for (final k in const [
      'displayName',
      'phoneNumber',
      'avatarUrl',
      'createdAt',
      'status',
      'email',
    ]) {
      if (cleaned.containsKey(k)) profilePatch[k] = cleaned[k];
    }
    if (profilePatch.isNotEmpty) {
      final profileUri = routes.updateAuthUserProfile(uid);
      final ok = await tryCall(
        'PATCH/profile',
        () => client.dio.patchUri(
          profileUri,
          data: profilePatch,
          options: Options(contentType: contentType),
        ),
      );
      any = any || ok;
    }

    if (any) return;

    // 4) Last resorts on main route with alternate shapes (some older handlers expect these)
    if (await tryCall(
      'PATCH/withUid',
      () => client.dio.patchUri(
        uriMain,
        data: {'uid': uid, ...cleaned},
        options: Options(contentType: contentType),
      ),
    )) {
      return;
    }
    if (await tryCall(
      'PATCH/wrapped',
      () => client.dio.patchUri(
        uriMain,
        data: {'updates': cleaned},
        options: Options(contentType: contentType),
      ),
    )) {
      return;
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
