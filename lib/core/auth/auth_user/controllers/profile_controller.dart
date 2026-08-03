// lib/core/auth_users/controllers/profile/profile_controller.dart

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth/auth_user/extensions/user_status_x.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/auth/auth_user/services/user_profile_service.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/widgets/shared/home_shell.dart';
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

  // ────────────────────────────────────────────
  // SOT helpers
  // ────────────────────────────────────────────

  /// Role assignment policy:
  /// - superadmin can assign anything
  /// - otherwise, any of editor's roles must allow assigning the target role
  bool _canAssignRole(AuthUser editor, StaffRole targetRole) {
    if (editor.isSuperAdmin) return true;
    if (editor.staffRoles.isEmpty) return false;
    return editor.staffRoles.any((r) => r.canAssignRole(targetRole));
  }

  List<StaffRole> _effectiveTargetRoles(AuthUser target) {
    return List<StaffRole>.from(state.staffRoleOverrides ?? target.staffRoles);
  }

  List<String> _effectiveTargetStores(AuthUser target) {
    return List<String>.from(state.storeOverrides ?? target.stores);
  }

  // ────────────────────────────────────────────
  // Init
  // ────────────────────────────────────────────

  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    final sessionUser = ref.read(currentUserValueProvider);
    final baseUser = targetUser ?? sessionUser;

    // Admin editing is ONLY when:
    // - session user exists
    // - target user exists
    // - SOT permission says editor can manage target
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

      final u = baseUser;
      if (u != null) {
        // Use displayName field for editing (not computed fallback)
        state.nameController.text = (u.displayName ?? '').trim();
        state.phoneController.text = (u.phoneNumber ?? '').trim();
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
  // Admin-edit setters (SOT gates)
  // ────────────────────────────────────────────

  void setStatus(UserStatus status) {
    final target = state.user;
    final editor = ref.read(currentUserValueProvider);

    if (target == null || editor == null) return;
    if (!editor.canChangeStatusFor(target)) return;

    if (status.isDisabled && !editor.canDisableUser(target)) {
      SnackService.showError("You can't disable this account.");
      return;
    }

    state = state.copyWith(statusOverride: status);
  }

  void toggleStaffRole(StaffRole role) {
    final target = state.user;
    final editor = ref.read(currentUserValueProvider);

    if (target == null || editor == null) return;
    if (!editor.canEditUserRolesFor(target)) return;

    final roles = _effectiveTargetRoles(target);
    final idx = roles.indexOf(role);
    final removing = idx >= 0;

    if (removing) {
      // Safety (future-proof): prevent removing owner role from self if you ever allow self edits
      if (editor.uid == target.uid && role == StaffRole.owner) {
        SnackService.showError(
          "You can't remove the Owner role from yourself.",
        );
        return;
      }

      // Safety (future-proof): don't allow removing last governance role from self
      if (editor.uid == target.uid && role == StaffRole.admin) {
        final remaining = roles.where((r) => r != role).toList();
        final stillGovernance = remaining.any(
          (r) => r == StaffRole.owner || r == StaffRole.admin,
        );
        if (!stillGovernance) {
          SnackService.showError(
            "You can't remove your last owner/admin role.",
          );
          return;
        }
      }

      roles.removeAt(idx);
    } else {
      if (!_canAssignRole(editor, role)) {
        SnackService.showError("You can't assign the ${role.label} role.");
        return;
      }
      roles.add(role);
    }

    state = state.copyWith(staffRoleOverrides: roles);
  }

  void toggleStore(String storeId) {
    final target = state.user;
    final editor = ref.read(currentUserValueProvider);

    if (target == null || editor == null) return;
    if (!editor.canEditUserStoresFor(target)) return;

    final stores = _effectiveTargetStores(target);

    if (stores.contains(storeId)) {
      stores.remove(storeId);
    } else {
      stores.add(storeId);
    }

    state = state.copyWith(storeOverrides: stores);
  }

  // ────────────────────────────────────────────
  // Save / PATCH via UserProfileService
  // ────────────────────────────────────────────

  Future<void> save(BuildContext context) async {
    final target = state.user;
    if (target == null || !mounted) return;

    final editor = ref.read(currentUserValueProvider);
    final name = state.nameController.text.trim();

    if (name.isEmpty) {
      SnackService.showError('Display name is required.');
      return;
    }

    final fields = <String, dynamic>{};

    // Everyone can edit their display name (self profile path)
    if (name != (target.displayName ?? '').trim()) {
      fields['displayName'] = name;
    }

    // Admin path: status/roles/stores (all SOT-gated)
    if (state.isAdminEditing && editor != null) {
      // STATUS
      if (editor.canChangeStatusFor(target)) {
        final nextStatus = state.statusOverride ?? target.status;
        if (nextStatus != target.status) {
          if (nextStatus.isDisabled && !editor.canDisableUser(target)) {
            SnackService.showError("You can't disable this account.");
          } else {
            fields['status'] = nextStatus.wire;
          }
        }
      }

      // STAFF ROLES
      if (editor.canEditUserRolesFor(target)) {
        final desiredRoles = _effectiveTargetRoles(target);

        // Enforce assignment policy: editor may only assign roles they are allowed to assign.
        final filteredRoles = desiredRoles
            .where((r) => _canAssignRole(editor, r))
            .toList(growable: false);

        // Safety (future-proof): if ever editing self in future, ensure governance not lost
        if (editor.uid == target.uid) {
          final hasGovernance = filteredRoles.any(
            (r) => r == StaffRole.owner || r == StaffRole.admin,
          );
          if (!hasGovernance) {
            SnackService.showError(
              "You can't remove your last owner/admin role.",
            );
          } else if (!listEquals(filteredRoles, target.staffRoles)) {
            fields['staffRoles'] = filteredRoles
                .map((r) => r.wire)
                .toList(growable: false);
          }
        } else {
          if (!listEquals(filteredRoles, target.staffRoles)) {
            fields['staffRoles'] = filteredRoles
                .map((r) => r.wire)
                .toList(growable: false);
          }
        }
      }

      // STORES
      if (editor.canEditUserStoresFor(target)) {
        final desiredStores = _effectiveTargetStores(target);
        if (!listEquals(desiredStores, target.stores)) {
          fields['stores'] = desiredStores;
        }
      }
    }

    if (fields.isEmpty) {
      SnackService.showSuccess('No changes to save.');
      return;
    }

    state = state.copyWith(loading: true);

    try {
      final tenantId = (editor ?? target).tenantId;
      final svc = await ref.read(userProfileServiceProvider(tenantId).future);
      await svc.updateUserFields(target.uid, fields);

      SnackService.showSuccess('Profile updated');

      _afterFrame(() {
        if (!mounted) return;

        // Admin editing a target → close back to list/detail
        if (state.isAdminEditing) {
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          return;
        }

        // Self-edit → refresh session user and restart shell
        ref.invalidate(currentUserProvider);
        ref.invalidate(currentUserValueProvider);

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeShell()),
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
    state.nameController.dispose();
    state.phoneController.dispose();
    super.dispose();
  }
}
