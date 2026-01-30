// lib/core/auth_users/controllers/profile/profile_controller.dart

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth/auth_user/extensions/user_status_x.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_user_providers.dart';
import 'package:afyakit/core/auth/auth_user/services/user_profile_service.dart';
import 'package:afyakit/features/home/widgets/tenant_home_shell.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sentinel to allow copyWith(null) for overrides.
class _Unset {
  const _Unset();
}

const _unset = _Unset();

@immutable
class ProfileFormState {
  final bool loading;
  final AuthUser? user;

  // Controllers live here by design in your app.
  // We MUST dispose them in the notifier.
  final TextEditingController nameController;
  final TextEditingController phoneController;

  /// True when a privileged user is editing via the "admin" path
  /// (roles/stores/status visible for the target).
  final bool isAdminEditing;

  /// Admin overrides (null = use user.* from model)
  final UserStatus? statusOverride;
  final List<StaffRole>? staffRoleOverrides;
  final List<String>? storeOverrides;

  const ProfileFormState({
    required this.loading,
    required this.user,
    required this.nameController,
    required this.phoneController,
    required this.isAdminEditing,
    required this.statusOverride,
    required this.staffRoleOverrides,
    required this.storeOverrides,
  });

  factory ProfileFormState.initial() => ProfileFormState(
    loading: true,
    user: null,
    nameController: TextEditingController(),
    phoneController: TextEditingController(),
    isAdminEditing: false,
    statusOverride: null,
    staffRoleOverrides: null,
    storeOverrides: null,
  );

  ProfileFormState copyWith({
    bool? loading,
    AuthUser? user,
    TextEditingController? nameController,
    TextEditingController? phoneController,
    bool? isAdminEditing,

    // Use sentinel so we can clear overrides to null.
    Object? statusOverride = _unset,
    Object? staffRoleOverrides = _unset,
    Object? storeOverrides = _unset,
  }) {
    return ProfileFormState(
      loading: loading ?? this.loading,
      user: user ?? this.user,
      nameController: nameController ?? this.nameController,
      phoneController: phoneController ?? this.phoneController,
      isAdminEditing: isAdminEditing ?? this.isAdminEditing,
      statusOverride: identical(statusOverride, _unset)
          ? this.statusOverride
          : statusOverride as UserStatus?,
      staffRoleOverrides: identical(staffRoleOverrides, _unset)
          ? this.staffRoleOverrides
          : staffRoleOverrides as List<StaffRole>?,
      storeOverrides: identical(storeOverrides, _unset)
          ? this.storeOverrides
          : storeOverrides as List<String>?,
    );
  }
}

// FAMILY: pass target user; null = current session user (self profile)
final profileControllerProvider =
    AutoDisposeStateNotifierProviderFamily<
      ProfileController,
      ProfileFormState,
      AuthUser?
    >((ref, targetUser) => ProfileController(ref, targetUser));

class ProfileController extends StateNotifier<ProfileFormState> {
  ProfileController(this.ref, this.targetUser)
    : super(ProfileFormState.initial());

  final Ref ref;

  /// If null → edit current logged-in user.
  /// If non-null → admin editing this specific user.
  final AuthUser? targetUser;

  bool _inited = false;

  void _afterFrame(VoidCallback fn) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) fn();
    });
  }

  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    final sessionUser = ref.read(currentUserValueProvider);
    final baseUser = targetUser ?? sessionUser;

    // Admin editing path:
    // - you must pass targetUser
    // - and the current user must be allowed to manage that target
    final isAdminEditing =
        (sessionUser != null &&
        targetUser != null &&
        sessionUser.canManageUser(targetUser!));

    _afterFrame(() {
      state = state.copyWith(
        loading: false,
        user: baseUser,
        isAdminEditing: isAdminEditing,
      );

      // Fill controllers safely.
      final u = baseUser;
      if (u != null) {
        state.nameController.text = (u.displayName ?? '').trim();
        state.phoneController.text = (u.phoneNumber).trim();
      }
    });
  }

  // ────────────────────────────────────────────
  // Override helpers
  // ────────────────────────────────────────────

  void clearAdminOverrides() {
    if (!mounted) return;
    state = state.copyWith(
      statusOverride: null,
      staffRoleOverrides: null,
      storeOverrides: null,
    );
  }

  // ────────────────────────────────────────────
  // Admin-edit setters
  // ────────────────────────────────────────────

  void setStatus(UserStatus status) {
    final target = state.user;
    final current = ref.read(currentUserValueProvider);

    if (target == null || current == null) return;
    if (!current.canChangeStatusFor(target)) return;

    // Extra guard: admin/owner cannot disable themselves,
    // and admins cannot disable owners.
    if (status.isDisabled && !current.canDisableUser(target)) {
      SnackService.showError("You can't disable this account.");
      return;
    }

    state = state.copyWith(statusOverride: status);
  }

  void toggleStaffRole(StaffRole role) {
    final target = state.user;
    final current = ref.read(currentUserValueProvider);

    if (target == null || current == null) return;
    if (!current.canEditUserRolesFor(target)) return;

    final currentRoles = List<StaffRole>.from(
      state.staffRoleOverrides ?? target.staffRoles,
    );

    final idx = currentRoles.indexWhere((r) => r == role);
    final removing = idx >= 0;

    if (removing) {
      // ── SAFETY 1: owner cannot remove OWNER from self ───────────────
      if (current.uid == target.uid && role.isOwner) {
        SnackService.showError(
          "You can't remove the Owner role from yourself.",
        );
        return;
      }

      // ── SAFETY 2: don't let anyone remove their last governance role ─
      if (current.uid == target.uid && role.isAdmin) {
        final remaining = currentRoles.where((r) => r != role).toList();
        final stillGovernance = remaining.any((r) => r.isOwner || r.isAdmin);
        if (!stillGovernance) {
          SnackService.showError(
            "You can't remove your last owner/admin role.",
          );
          return;
        }
      }

      currentRoles.removeAt(idx);
    } else {
      final canAssign =
          current.isSuperAdmin ||
          current.isOwner ||
          current.staffRoles.any((r) => r.canAssignRole(role));

      if (!canAssign) {
        SnackService.showError("You can't assign the ${role.label} role.");
        return;
      }

      currentRoles.add(role);
    }

    state = state.copyWith(staffRoleOverrides: currentRoles);
  }

  void toggleStore(String storeId) {
    final target = state.user;
    final current = ref.read(currentUserValueProvider);

    if (target == null || current == null) return;
    if (!current.canEditUserStoresFor(target)) return;

    final currentStores = List<String>.from(
      state.storeOverrides ?? target.stores,
    );

    if (currentStores.contains(storeId)) {
      currentStores.remove(storeId);
    } else {
      currentStores.add(storeId);
    }

    state = state.copyWith(storeOverrides: currentStores);
  }

  // ────────────────────────────────────────────
  // Save / PATCH via UserProfileService
  // ────────────────────────────────────────────

  Future<void> save(BuildContext context) async {
    final user = state.user;
    if (user == null || !mounted) return;

    final sessionUser = ref.read(currentUserValueProvider);
    final name = state.nameController.text.trim();

    if (name.isEmpty) {
      SnackService.showError('Display name is required.');
      return;
    }

    final fields = <String, dynamic>{};

    // All users can edit their display name
    if (name != (user.displayName ?? '').trim()) {
      fields['displayName'] = name;
    }

    // NOTE:
    // Phone editing is intentionally NOT persisted here.
    // If you want it, we must:
    // - normalize E.164
    // - restrict to self only OR to privileged admins
    // - likely require re-verification
    // Keeping it read-only is safest.

    if (state.isAdminEditing && sessionUser != null) {
      // ── STATUS ────────────────────────────────
      if (sessionUser.canChangeStatusFor(user)) {
        final newStatus = state.statusOverride ?? user.status;
        if (newStatus != user.status) {
          if (newStatus.isDisabled && !sessionUser.canDisableUser(user)) {
            SnackService.showError("You can't disable this account.");
          } else {
            fields['status'] = newStatus.wire;
          }
        }
      }

      // ── STAFF ROLES ──────────────────────────
      if (sessionUser.canEditUserRolesFor(user)) {
        final newRoles = state.staffRoleOverrides ?? user.staffRoles;

        // Filter out any roles current user isn't allowed to assign.
        final filteredRoles = newRoles
            .where((role) {
              final canAssign =
                  sessionUser.isSuperAdmin ||
                  sessionUser.isOwner ||
                  sessionUser.staffRoles.any((r) => r.canAssignRole(role));
              return canAssign;
            })
            .toList(growable: false);

        // Extra safety for self: don't persist a self-demotion removing governance.
        if (sessionUser.uid == user.uid) {
          final hasGovernance = filteredRoles.any(
            (r) => r.isOwner || r.isAdmin,
          );
          if (!hasGovernance) {
            SnackService.showError(
              "You can't remove your last owner/admin role.",
            );
          } else if (!listEquals(filteredRoles, user.staffRoles)) {
            fields['staffRoles'] = filteredRoles.map((r) => r.wire).toList();
          }
        } else {
          if (!listEquals(filteredRoles, user.staffRoles)) {
            fields['staffRoles'] = filteredRoles.map((r) => r.wire).toList();
          }
        }
      }

      // ── STORES ───────────────────────────────
      if (sessionUser.canEditUserStoresFor(user)) {
        final newStores = state.storeOverrides ?? user.stores;
        if (!listEquals(newStores, user.stores)) {
          fields['stores'] = newStores;
        }
      }
    }

    // Nothing changed → no-op
    if (fields.isEmpty) {
      SnackService.showSuccess('No changes to save.');
      return;
    }

    state = state.copyWith(loading: true);

    try {
      // Resolve tenantId for the service. Prefer session user if available.
      final tenantId = (sessionUser ?? user).tenantId;

      final svc = await ref.read(userProfileServiceProvider(tenantId).future);
      await svc.updateUserFields(user.uid, fields);

      SnackService.showSuccess('Profile updated');

      _afterFrame(() {
        if (!mounted) return;

        if (state.isAdminEditing) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          return;
        }

        // ✅ Self-profile: refresh session user + go back to canonical home shell.
        ref.invalidate(currentUserProvider);
        ref.invalidate(currentUserValueProvider);

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const TenantHomeShell()),
          (_) => false,
        );
      });
    } catch (_) {
      SnackService.showError('Failed to update profile.');
    } finally {
      _afterFrame(() {
        if (!mounted) return;
        state = state.copyWith(loading: false);
      });
    }
  }

  @override
  void dispose() {
    // ✅ critical: controllers must be disposed.
    state.nameController.dispose();
    state.phoneController.dispose();
    super.dispose();
  }
}
