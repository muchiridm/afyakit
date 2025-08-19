// lib/users/user_manager/engines/user_manager_engine.dart

import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/types/app_error.dart';
import 'package:afyakit/users/user_manager/models/auth_user_model.dart';
import 'package:afyakit/users/user_manager/models/global_user_model.dart';
import 'package:afyakit/users/user_manager/models/super_admim_model.dart';
import 'package:afyakit/users/user_manager/services/user_manager_service.dart'
    show UserManagerService, UpdateProfileRequest;
import 'package:afyakit/users/user_manager/extensions/user_role_x.dart'
    show UserRole;
import 'package:afyakit/users/user_manager/extensions/user_status_x.dart'
    show UserStatus;

class UserManagerEngine {
  final UserManagerService service;
  UserManagerEngine(this.service);

  // ─────────────────────────────────────────────────────────────
  // ✉️ Invites (string role → enum, tolerant)
  // ─────────────────────────────────────────────────────────────
  Future<Result<void>> invite({
    String? email,
    String? phoneNumber,
    String? role, // 'owner'|'admin'|'manager'|'staff'|'client'|null
    bool forceResend = false,
  }) async {
    try {
      if ((email == null || email.isEmpty) &&
          (phoneNumber == null || phoneNumber.isEmpty)) {
        return Err(AppError('auth/bad-invite', 'Email or phone is required'));
      }

      final UserRole resolvedRole = _parseRole(role);

      await service.inviteUser(
        email: email,
        phoneNumber: phoneNumber,
        role: resolvedRole,
        forceResend: forceResend,
      );
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/invite-failed', 'Invite failed', cause: e));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 👀 Read
  // ─────────────────────────────────────────────────────────────
  Future<Result<AuthUser>> byId(String uid) async {
    try {
      final user = await service.getUserById(uid);
      return Ok(user);
    } catch (e) {
      return Err(AppError('auth/get-failed', 'Failed to load user', cause: e));
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

  // ─────────────────────────────────────────────────────────────
  // ✏️ Write (compat shim over new typed service)
  // Splits generic updates into profile / membership calls.
  // Supported keys: displayName, phoneNumber, avatarUrl, role, status, stores
  // ─────────────────────────────────────────────────────────────
  Future<Result<void>> updateFields(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    try {
      // normalize keys and read values
      String? s0(String key) {
        final v = updates[key];
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }

      // profile chunk
      final profileReq = UpdateProfileRequest(
        displayName: s0('displayName'),
        phoneNumber: s0('phoneNumber'),
        avatarUrl: s0('avatarUrl'),
      );
      if (profileReq.toJson().isNotEmpty) {
        await service.updateProfile(uid, profileReq);
      }

      // role
      final roleStr = s0('role');
      if (roleStr != null) {
        await service.assignRole(uid, _parseRole(roleStr));
      }

      // status
      final statusStr = s0('status');
      if (statusStr != null) {
        await service.setStatus(uid, _parseStatus(statusStr));
      }

      // stores
      final storesRaw = updates['stores'];
      final List<String>? stores = switch (storesRaw) {
        List l =>
          l.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList(),
        String s when s.trim().isNotEmpty =>
          s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        _ => null,
      };
      if (stores != null) {
        await service.setStores(uid, stores);
      }

      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/update-failed', 'Update failed', cause: e));
    }
  }

  Future<Result<void>> setProfile(
    String uid, {
    String? displayName,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    try {
      final req = UpdateProfileRequest(
        displayName: displayName,
        phoneNumber: phoneNumber,
        avatarUrl: avatarUrl,
      );
      await service.updateProfile(uid, req);
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError(
          'auth/update-profile-failed',
          'Profile update failed',
          cause: e,
        ),
      );
    }
  }

  Future<Result<void>> setRole(String uid, String role) async {
    try {
      await service.assignRole(uid, _parseRole(role));
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError('auth/update-role-failed', 'Role update failed', cause: e),
      );
    }
  }

  Future<Result<void>> setStores(String uid, List<String> stores) async {
    try {
      await service.setStores(uid, stores);
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError('auth/update-stores-failed', 'Stores update failed', cause: e),
      );
    }
  }

  Future<Result<void>> activate(String uid) async {
    try {
      await service.activateUser(uid);
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/activate-failed', 'Activate failed', cause: e));
    }
  }

  Future<Result<void>> disable(String uid) async {
    try {
      await service.disableUser(uid);
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/disable-failed', 'Disable failed', cause: e));
    }
  }

  /// Convenience: invited → active (+ optional phone)
  Future<Result<void>> promoteInvite(String uid, {String? phoneNumber}) async {
    try {
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
        await service.updateProfile(
          uid,
          UpdateProfileRequest(phoneNumber: phoneNumber.trim()),
        );
      }
      await service.activateUser(uid);
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError('auth/promote-failed', 'Failed to promote invite', cause: e),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 🗑️ Delete
  // ─────────────────────────────────────────────────────────────
  Future<Result<void>> delete(String uid) async {
    try {
      await service.deleteUser(uid);
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/delete-failed', 'Delete failed', cause: e));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // helpers
  // ─────────────────────────────────────────────────────────────
  UserRole _parseRole(String? r) {
    if (r == null || r.trim().isEmpty) return UserRole.staff;
    final s = r.trim().toLowerCase();
    switch (s) {
      case 'owner':
        return UserRole.owner;
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'client':
        return UserRole.client;
      case 'staff':
        return UserRole.staff;
      // legacy/unknown → default to admin (old behavior) or staff?
      default:
        return UserRole.admin;
    }
  }

  UserStatus _parseStatus(String s) {
    switch (s.trim().toLowerCase()) {
      case 'active':
        return UserStatus.active;
      case 'disabled':
        return UserStatus.disabled;
      case 'invited':
      default:
        return UserStatus.invited;
    }
  }

  Future<Result<List<GlobalUser>>> hqUsers({
    String? tenantId,
    String search = '',
    int limit = 50,
  }) async {
    try {
      final list = await service.fetchGlobalUsers(
        tenantId: tenantId,
        search: search,
        limit: limit,
      );
      return Ok(list);
    } catch (e) {
      return Err(
        AppError('hq/users-failed', 'Failed to load global users', cause: e),
      );
    }
  }

  Future<Result<Map<String, Map<String, Object?>>>> fetchUserMemberships(
    String uid,
  ) async {
    try {
      final map = await service.fetchUserMemberships(uid);
      return Ok(map);
    } catch (e) {
      return Err(
        AppError(
          'hq/memberships-failed',
          'Failed to load memberships',
          cause: e,
        ),
      );
    }
  }

  /// HQ: list all superadmins
  Future<Result<List<SuperAdmin>>> listSuperAdmins() async {
    try {
      final list = await service.listSuperAdmins();
      return Ok(list);
    } catch (e) {
      return Err(
        AppError(
          'hq/superadmins-list-failed',
          'Failed to load superadmins',
          cause: e,
        ),
      );
    }
  }

  /// HQ: toggle superadmin on/off for a uid
  Future<Result<void>> setSuperAdmin({
    required String uid,
    required bool value,
  }) async {
    try {
      await service.setSuperAdmin(uid: uid, value: value);
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError(
          'hq/superadmins-set-failed',
          'Failed to update superadmin',
          cause: e,
        ),
      );
    }
  }
}
