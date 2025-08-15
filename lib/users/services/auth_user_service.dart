import 'dart:convert';
import 'package:afyakit/shared/api/api_client.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:afyakit/users/models/auth_user_model.dart';
import 'package:flutter/material.dart';

class AuthUserService {
  final ApiClient client;
  final ApiRoutes routes;

  AuthUserService({required this.client, required this.routes});

  /// 📩 Invite or Reinvite a user
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

    final payload = {
      if (cleanedEmail.isNotEmpty) 'email': cleanedEmail,
      if (cleanedPhone.isNotEmpty) 'phoneNumber': cleanedPhone,
      if (forceResend) 'forceResend': true,
    };

    try {
      final res = await client.dio.postUri(routes.inviteUser(), data: payload);

      if (res.statusCode != 200 && res.statusCode != 201) {
        final reason = res.data?['error'] ?? 'Unknown error';
        throw Exception('❌ Failed to invite user: $reason');
      }

      final identifier = cleanedEmail.isNotEmpty ? cleanedEmail : cleanedPhone;
      debugPrint('✅ User invited/resend: $identifier');
    } catch (e) {
      debugPrint('❌ Invite failed: $e');
      rethrow;
    }
  }

  /// 🔍 Get user by ID
  Future<AuthUser> getUserById(String uid) async {
    final res = await client.dio.getUri(routes.getUserById(uid));
    final raw = res.data;

    if (raw == null || raw is! Map) {
      throw Exception('❌ getUserById: Invalid response → ${raw.runtimeType}');
    }

    final safeMap = Map<String, dynamic>.from(jsonDecode(jsonEncode(raw)));
    final user = AuthUser.fromJson(safeMap);
    debugPrint('✅ Loaded user: ${user.email} (${user.uid})');
    return user;
  }

  /// 📄 Get all users
  Future<List<AuthUser>> getAllUsers() async {
    try {
      final response = await client.dio.getUri(routes.getAllUsers());
      final data = response.data as List<dynamic>;

      final users = data
          .whereType<Map<String, dynamic>>()
          .map(AuthUser.fromJson)
          .where((u) => u.uid.isNotEmpty)
          .toList();

      debugPrint('✅ Loaded ${users.length} users');
      return users;
    } catch (e) {
      debugPrint('❌ [getAllUsers] Failed: $e');
      return [];
    }
  }

  /// 🧨 Delete user
  Future<void> deleteUser(String uid) async {
    await client.dio.deleteUri(routes.deleteUser(uid));
    debugPrint('🗑️ User deleted: $uid');
  }

  /// 🛠️ Update user fields (e.g. phoneNumber, email)
  Future<void> updateAuthUserFields(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    if (updates.isEmpty) {
      throw ArgumentError('❌ No fields provided for update');
    }

    final uri = routes.updateUser(uid);
    debugPrint('🌍 [Service] PUT URI: $uri');
    debugPrint('📦 [Service] Payload: $updates');

    try {
      await client.dio.putUri(uri, data: updates);
      debugPrint('✅ [Service] PUT successful');
    } catch (e, st) {
      debugPrint('❌ [Service] PUT failed: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }
}
