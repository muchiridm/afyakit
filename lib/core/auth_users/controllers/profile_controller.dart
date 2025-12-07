// lib/core/auth_users/controllers/profile/profile_controller.dart

import 'package:afyakit/core/auth_users/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth_users/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth_users/extensions/user_status_x.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/providers/current_user_providers.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/widgets/home_screens/home_screen.dart';

class ProfileFormState {
  final bool loading;
  final AuthUser? user;
  final TextEditingController nameController;
  final TextEditingController phoneController;

  /// True when a privileged user is editing via the "admin" path
  /// (roles/stores/status visible for the target).
  final bool isAdminEditing;

  /// Admin overrides (null = use user.* from model)
  final UserStatus? statusOverride;
  final List<StaffRole>? staffRoleOverrides;
  final List<String>? storeOverrides;

  ProfileFormState({
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
    UserStatus? statusOverride,
    List<StaffRole>? staffRoleOverrides,
    List<String>? storeOverrides,
  }) {
    return ProfileFormState(
      loading: loading ?? this.loading,
      user: user ?? this.user,
      nameController: nameController ?? this.nameController,
      phoneController: phoneController ?? this.phoneController,
      isAdminEditing: isAdminEditing ?? this.isAdminEditing,
      statusOverride: statusOverride ?? this.statusOverride,
      staffRoleOverrides: staffRoleOverrides ?? this.staffRoleOverrides,
      storeOverrides: storeOverrides ?? this.storeOverrides,
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

      if (baseUser != null) {
        state.nameController.text = baseUser.displayName;
        state.phoneController.text = baseUser.phoneNumber;
      }
    });
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
        final remaining = currentRoles
            .where((r) => r != role)
            .toList(growable: false);
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
      // Adding a role → respect assignment rules.
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
  // Save / PATCH
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
    if (name != user.displayName) {
      fields['displayName'] = name;
    }

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
        final filteredRoles = newRoles.where((role) {
          final canAssign =
              sessionUser.isSuperAdmin ||
              sessionUser.isOwner ||
              sessionUser.staffRoles.any((r) => r.canAssignRole(role));
          return canAssign;
        }).toList();

        // Extra safety for self: don't persist a self-demotion
        // that removes last governance role.
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
      await user.updateFields(ref, fields);
      SnackService.showSuccess('Profile updated');

      _afterFrame(() {
        if (state.isAdminEditing) {
          // Admin path → just pop back to manager
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        } else {
          // Self-profile: keep existing behavior
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (_) => false,
          );
        }
      });
    } catch (_) {
      SnackService.showError('Failed to update profile.');
    } finally {
      _afterFrame(() {
        state = state.copyWith(loading: false);
      });
    }
  }
}
