// lib/core/auth/auth_user/controllers/profile_controller.dart

import 'package:afyakit/app/providers/app_profile_provider.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
// lib/core/auth/auth_user/controllers/profile_controller.dart

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth/auth_user/extensions/user_status_x.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/auth/auth_user/services/user_profile_service.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/features/home/widgets/shared/home_shell.dart';
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
    >((ref, targetUser) {
      ref.watch(appIdProvider);
      ref.watch(tenantIdProvider);
      ref.watch(firebaseUserProvider.select((value) => value.valueOrNull?.uid));
      return ProfileController(ref, targetUser);
    });

class ProfileController extends StateNotifier<ProfileFormState> {
  ProfileController(this.ref, this.targetUser)
    : super(ProfileFormState.initial());

  final Ref ref;

  /// If null → edit current logged-in user.
  /// If non-null → admin editing this specific user.
  final AuthUser? targetUser;

  bool _inited = false;
  String? _actorUid;

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
    return List<StaffRole>.from(
      state.staffRoleOverrides ?? target.rolesForApp(target.activeAppId!),
    );
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

    AuthUser? loadedUser;
    try {
      loadedUser =
          ref.read(currentUserValueProvider) ??
          await ref.read(currentUserProvider.future);
    } catch (_) {
      if (mounted) {
        _inited = false;
        _afterFrame(() => state = state.copyWith(loading: false));
        SnackService.showError(
          'Could not load your account. Please reopen the profile.',
        );
      }
      return;
    }
    if (!mounted) return;
    final sessionUser = loadedUser;
    if (sessionUser == null) {
      _inited = false;
      _afterFrame(() => state = state.copyWith(loading: false));
      return;
    }
    _actorUid = sessionUser.uid;
    if (targetUser != null && targetUser!.tenantId != sessionUser.tenantId) {
      SnackService.showError('This account belongs to a different tenant.');
      _afterFrame(() => state = state.copyWith(loading: false));
      return;
    }
    final baseUser = (targetUser ?? sessionUser).forApp(
      sessionUser.activeAppId!,
    );

    // Admin editing is ONLY when:
    // - session user exists
    // - target user exists
    // - SOT permission says editor can manage target
    final isAdminEditing =
        (targetUser != null && sessionUser.canManageUser(baseUser));

    _afterFrame(() {
      state = state.copyWith(
        loading: false,
        user: baseUser,
        isAdminEditing: isAdminEditing,
      );

      final u = baseUser;
      // Use displayName field for editing (not computed fallback)
      state.nameController.text = (u.displayName ?? '').trim();
      state.phoneController.text = (u.phoneNumber ?? '').trim();
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
    if (!mounted || state.loading) return;
    final target = state.user;
    final editor = ref.read(currentUserValueProvider);
    if (target == null ||
        editor == null ||
        editor.uid != _actorUid ||
        target.tenantId != editor.tenantId ||
        target.activeAppId != editor.activeAppId) {
      SnackService.showError('Account or app changed. Reopen the profile.');
      return;
    }
    final fields = <String, dynamic>{};
    final name = state.nameController.text.trim();
    if (name != (target.displayName ?? '').trim()) {
      if (editor.uid != target.uid && !editor.canEditUserAccounts) {
        SnackService.showError(
          'Only platform administrators can edit another account profile.',
        );
        return;
      }
      if (name.isEmpty) {
        SnackService.showError('Display name is required.');
        return;
      }
      fields['displayName'] = name;
    }
    final nextStatus = state.statusOverride;
    if (nextStatus != null && nextStatus != target.status) {
      if (!editor.canChangeStatusFor(target)) {
        SnackService.showError('You cannot change this account status.');
        return;
      }
      fields['status'] = nextStatus.wire;
    }
    final stores = state.storeOverrides;
    if (stores != null && !listEquals(stores, target.stores)) {
      if (!editor.canEditUserStoresFor(target)) {
        SnackService.showError('You cannot change this account store access.');
        return;
      }
      fields['stores'] = stores;
    }
    final desiredRoles = _effectiveTargetRoles(target);
    final oldRoles = target.rolesForApp(target.activeAppId!);
    final rolesChanged = !setEquals(desiredRoles.toSet(), oldRoles.toSet());
    if (rolesChanged) {
      if (!editor.canEditUserRolesFor(target) ||
          desiredRoles.any((role) => !_canAssignRole(editor, role))) {
        SnackService.showError('You cannot make this app role change.');
        return;
      }
      if (desiredRoles.isNotEmpty && !(nextStatus ?? target.status).isActive) {
        SnackService.showError(
          'Enable the account before assigning app roles.',
        );
        return;
      }
    }
    if (fields.isEmpty && !rolesChanged) {
      SnackService.showSuccess('No changes to save.');
      return;
    }
    state = state.copyWith(loading: true);
    var profileSaved = false;
    bool sessionMatches() {
      if (!mounted) return false;
      final current = ref.read(currentUserValueProvider);
      return current?.uid == editor.uid &&
          current?.tenantId == editor.tenantId &&
          current?.activeAppId == editor.activeAppId;
    }

    try {
      final service = await ref.read(
        userProfileServiceProvider(editor.tenantId).future,
      );
      if (!sessionMatches() || service.appId != editor.activeAppId) {
        throw StateError('Account or app changed');
      }
      if (fields.isNotEmpty) {
        await service.updateUserFields(target.uid, fields);
        profileSaved = true;
      }
      if (rolesChanged) {
        if (!sessionMatches()) throw StateError('Account or app changed');
        await service.setAppStaffRoles(target.uid, desiredRoles);
      }
      if (!mounted || !context.mounted) return;
      if (!sessionMatches()) return;
      SnackService.showSuccess('Profile updated');
      ref.invalidate(currentUserProvider);
      if (state.isAdminEditing) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeShell()),
          (_) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        // Two API writes are not atomic. Keep role overrides so they can be retried.
        if (profileSaved) {
          state = state.copyWith(
            user: target.copyWith(
              displayName: fields['displayName'] as String?,
              status: nextStatus,
              stores: stores,
            ),
            statusOverride: null,
            storeOverrides: null,
          );
        }
        SnackService.showError(
          profileSaved
              ? 'Profile details were saved, but the app role change did not complete. Refresh and check roles before retrying.'
              : 'Update did not complete. Refresh and check the account before retrying.',
        );
      }
    } finally {
      if (mounted) state = state.copyWith(loading: false);
    }
  }

  @override
  void dispose() {
    state.nameController.dispose();
    state.phoneController.dispose();
    super.dispose();
  }
}
