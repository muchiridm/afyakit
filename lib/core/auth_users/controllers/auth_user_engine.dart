import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/types/app_error.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';

import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/extensions/user_role_x.dart';
import 'package:afyakit/core/auth_users/extensions/user_status_x.dart';

import 'package:afyakit/core/auth_users/services/auth_user_service.dart';
import 'package:afyakit/shared/types/dtos.dart';

/// Tenant-only engine: invites, reads, updates, deletes.
/// No HQ/global/superadmin stuff lives here anymore.
class AuthUserEngine {
  final AuthUserService _svc;
  AuthUserEngine(this._svc);

  // ─────────────────────────────────────────────────────────────
  // Invites (string role → enum, tolerant)
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
      final resolvedRole = _parseRole(role);
      await _svc.inviteUser(
        email: (email == null || email.trim().isEmpty)
            ? null
            : EmailHelper.normalize(email),
        phoneNumber: (phoneNumber == null || phoneNumber.trim().isEmpty)
            ? null
            : phoneNumber.trim(),
        role: resolvedRole,
        forceResend: forceResend,
      );
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/invite-failed', 'Invite failed', cause: e));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Reads (tenant-scoped)
  // ─────────────────────────────────────────────────────────────
  Future<Result<AuthUser>> byId(String uid) async {
    try {
      final user = await _svc.getUserById(uid);
      return Ok(user);
    } catch (e) {
      return Err(AppError('auth/get-failed', 'Failed to load user', cause: e));
    }
  }

  Future<Result<List<AuthUser>>> all() async {
    try {
      final users = await _svc.getAllUsers();
      return Ok(users);
    } catch (e) {
      return Err(
        AppError('auth/list-failed', 'Failed to load users', cause: e),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Writes (profile / membership / status)
  // Supported keys: displayName, phoneNumber, avatarUrl, role, status, stores
  // ─────────────────────────────────────────────────────────────
  Future<Result<void>> updateFields(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    try {
      String? s0(String key) {
        final v = updates[key];
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }

      // profile
      final profileReq = UpdateProfileRequest(
        displayName: s0('displayName'),
        phoneNumber: s0('phoneNumber'),
        avatarUrl: s0('avatarUrl'),
      );
      if (profileReq.toJson().isNotEmpty) {
        await _svc.updateProfile(uid, profileReq);
      }

      // role
      final roleStr = s0('role');
      if (roleStr != null) {
        await _svc.assignRole(uid, _parseRole(roleStr));
      }

      // status
      final statusStr = s0('status');
      if (statusStr != null) {
        await _svc.setStatus(uid, _parseStatus(statusStr));
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
        await _svc.setStores(uid, stores);
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
      await _svc.updateProfile(uid, req);
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
      await _svc.assignRole(uid, _parseRole(role));
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError('auth/update-role-failed', 'Role update failed', cause: e),
      );
    }
  }

  Future<Result<void>> setStores(String uid, List<String> stores) async {
    try {
      await _svc.setStores(uid, stores);
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError('auth/update-stores-failed', 'Stores update failed', cause: e),
      );
    }
  }

  Future<Result<void>> activate(String uid) async {
    try {
      await _svc.activateUser(uid);
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/activate-failed', 'Activate failed', cause: e));
    }
  }

  Future<Result<void>> disable(String uid) async {
    try {
      await _svc.disableUser(uid);
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/disable-failed', 'Disable failed', cause: e));
    }
  }

  /// Convenience: invited → active (+ optional phone)
  Future<Result<void>> promoteInvite(String uid, {String? phoneNumber}) async {
    try {
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
        await _svc.updateProfile(
          uid,
          UpdateProfileRequest(phoneNumber: phoneNumber.trim()),
        );
      }
      await _svc.activateUser(uid);
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError('auth/promote-failed', 'Failed to promote invite', cause: e),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Delete (tenant membership)
  // ─────────────────────────────────────────────────────────────
  Future<Result<void>> delete(String uid) async {
    try {
      await _svc.deleteUser(uid);
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
    switch (r.trim().toLowerCase()) {
      case 'owner':
        return UserRole.owner;
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'client':
        return UserRole.client;
      case 'staff':
      default:
        return UserRole.staff;
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
}
