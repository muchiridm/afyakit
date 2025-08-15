// lib/users/engines/auth_user_engine.dart
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/types/app_error.dart';
import 'package:afyakit/users/models/auth_user_model.dart';
import 'package:afyakit/users/services/auth_user_service.dart';

class AuthUserEngine {
  final AuthUserService service;
  AuthUserEngine(this.service);

  Future<Result<void>> invite(String email, {bool forceResend = false}) async {
    try {
      await service.inviteUser(email: email, forceResend: forceResend);
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/invite-failed', 'Invite failed', cause: e));
    }
  }

  Future<Result<void>> updateFields(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    try {
      await service.updateAuthUserFields(uid, updates);
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/update-failed', 'Update failed', cause: e));
    }
  }

  Future<Result<List<AuthUser>>> all() async {
    try {
      final users = await service.getAllUsers();
      return Ok(users);
    } catch (e) {
      return Err(
        AppError('auth/list-failed', 'Failed to load users', cause: e),
      );
    }
  }

  Future<Result<AuthUser?>> byId(String uid) async {
    try {
      final user = await service.getUserById(uid);
      return Ok(user);
    } catch (e) {
      return Err(AppError('auth/get-failed', 'Failed to load user', cause: e));
    }
  }
}
