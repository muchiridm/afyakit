import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/hq/users/all_users/all_user_model.dart';
import 'package:afyakit/core/hq/users/all_users/controllers/all_users_controller.dart';
import 'package:afyakit/shared/services/snack_service.dart';

/// UI access levels (maps deterministically to tenant auth_user fields).
enum AccessLevel {
  member,
  staff,
  manager,
  admin,
  owner;

  String get label {
    switch (this) {
      case AccessLevel.member:
        return 'Member';
      case AccessLevel.staff:
        return 'Staff';
      case AccessLevel.manager:
        return 'Manager';
      case AccessLevel.admin:
        return 'Admin';
      case AccessLevel.owner:
        return 'Owner';
    }
  }

  /// Directory membership "role" (users/{uid}/memberships/{tenantId}).
  String get membershipRole {
    switch (this) {
      case AccessLevel.member:
        return 'client';
      case AccessLevel.staff:
        return 'staff';
      case AccessLevel.manager:
        return 'manager';
      case AccessLevel.admin:
        return 'admin';
      case AccessLevel.owner:
        return 'owner';
    }
  }

  /// Tenant auth_user patch "type"
  String get userTypeForTenantAuthUser {
    switch (this) {
      case AccessLevel.member:
        return 'member';
      case AccessLevel.staff:
      case AccessLevel.manager:
      case AccessLevel.admin:
      case AccessLevel.owner:
        return 'staff';
    }
  }

  /// Tenant auth_user patch staffRoles (always send; empty allowed)
  List<String> get staffRolesForTenantAuthUser {
    switch (this) {
      case AccessLevel.member:
        return const <String>[];
      case AccessLevel.staff:
        return const <String>[];
      case AccessLevel.manager:
        return const <String>['manager'];
      case AccessLevel.admin:
        return const <String>['admin'];
      case AccessLevel.owner:
        return const <String>['owner'];
    }
  }

  static AccessLevel fromMembershipRole(String? roleRaw) {
    final r = (roleRaw ?? '').trim().toLowerCase();
    switch (r) {
      case 'owner':
        return AccessLevel.owner;
      case 'admin':
        return AccessLevel.admin;
      case 'manager':
        return AccessLevel.manager;
      case 'staff':
        return AccessLevel.staff;
      case 'client':
      default:
        return AccessLevel.member;
    }
  }
}

@immutable
class UserEditorArgs {
  const UserEditorArgs({
    required this.targetTenantId,
    required this.uid,
    this.initialUser,
  });

  final String targetTenantId;
  final String uid;
  final AllUser? initialUser;
}

@immutable
class UserEditorState {
  const UserEditorState({
    required this.targetTenantId,
    required this.uid,
    this.initialUser,
    this.loadingMemberships = false,
    this.saving = false,
    this.deleting = false,
    this.didInitialPrefill = false,
    this.level = AccessLevel.member,
    this.active = true,
    this.tenantEmail,
    this.hasAccess = false,
    this.allMemberships,
  });

  final String targetTenantId;
  final String uid;
  final AllUser? initialUser;

  final bool loadingMemberships;
  final bool saving;
  final bool deleting;

  final bool didInitialPrefill;

  final AccessLevel level;
  final bool active;
  final String? tenantEmail;

  final bool hasAccess;

  /// uid -> { tenantId -> { role, active, email? } }
  final Map<String, Map<String, Object?>>? allMemberships;

  UserEditorState copyWith({
    bool? loadingMemberships,
    bool? saving,
    bool? deleting,
    bool? didInitialPrefill,
    AccessLevel? level,
    bool? active,
    String? tenantEmail,
    bool tenantEmailSet = false, // allow explicit null
    bool? hasAccess,
    Map<String, Map<String, Object?>>? allMemberships,
    bool allMembershipsSet = false,
  }) {
    return UserEditorState(
      targetTenantId: targetTenantId,
      uid: uid,
      initialUser: initialUser,
      loadingMemberships: loadingMemberships ?? this.loadingMemberships,
      saving: saving ?? this.saving,
      deleting: deleting ?? this.deleting,
      didInitialPrefill: didInitialPrefill ?? this.didInitialPrefill,
      level: level ?? this.level,
      active: active ?? this.active,
      tenantEmail: tenantEmailSet ? tenantEmail : this.tenantEmail,
      hasAccess: hasAccess ?? this.hasAccess,
      allMemberships: allMembershipsSet ? allMemberships : this.allMemberships,
    );
  }
}

final userEditorControllerProvider = StateNotifierProvider.autoDispose
    .family<UserEditorController, UserEditorState, UserEditorArgs>((ref, args) {
      return UserEditorController(ref, args);
    });

class UserEditorController extends StateNotifier<UserEditorState> {
  UserEditorController(this.ref, UserEditorArgs args)
    : super(
        UserEditorState(
          targetTenantId: args.targetTenantId.trim(),
          uid: args.uid.trim(),
          initialUser: args.initialUser,
        ),
      ) {
    // fire-and-forget init
    // ignore: discarded_futures
    init();
  }

  final Ref ref;

  String get _t => state.targetTenantId.trim();
  String get _u => state.uid.trim();

  Future<void> init() async {
    if (_t.isEmpty || _u.isEmpty) return;

    state = state.copyWith(loadingMemberships: true);

    try {
      final allUsers = ref.read(allUsersControllerProvider.notifier);

      // Pull memberships (cached or fetched).
      final mems = await allUsers.fetchMemberships(_u);

      _applyMembershipsToState(mems, allowPrefill: true);

      // Ensure the cache stays accurate on first load too.
      // (If you want a guaranteed refresh, call refreshMemberships(force: true))
    } catch (e) {
      SnackService.showError('❌ Failed to load memberships: $e');
    } finally {
      if (mounted) state = state.copyWith(loadingMemberships: false);
    }
  }

  void setAccessLevel(AccessLevel level) {
    state = state.copyWith(level: level);
  }

  void setActive(bool v) {
    state = state.copyWith(active: v);
  }

  Future<void> refreshMemberships({bool force = true}) async {
    if (_t.isEmpty || _u.isEmpty) return;

    state = state.copyWith(loadingMemberships: true);

    try {
      final allUsers = ref.read(allUsersControllerProvider.notifier);

      if (force) {
        await allUsers.refreshMembershipsForUid(_u);
      }

      final mems = await allUsers.fetchMemberships(_u);
      _applyMembershipsToState(mems, allowPrefill: !state.didInitialPrefill);
    } catch (e) {
      SnackService.showError('❌ Failed to refresh memberships: $e');
    } finally {
      if (mounted) state = state.copyWith(loadingMemberships: false);
    }
  }

  void _applyMembershipsToState(
    Map<String, Map<String, Object?>> mems, {
    required bool allowPrefill,
  }) {
    final tenantMem = mems[_t];
    final hasAccess = tenantMem != null;

    // Keep a copy in editor state so UI doesn't need to read AllUsersController directly.
    var next = state.copyWith(
      hasAccess: hasAccess,
      allMemberships: mems,
      allMembershipsSet: true,
    );

    if (allowPrefill && !next.didInitialPrefill && tenantMem != null) {
      final role = (tenantMem['role'] as String?)?.trim();
      final active = tenantMem['active'] == true;
      final email = (tenantMem['email'] as String?)?.trim();

      next = next.copyWith(
        level: AccessLevel.fromMembershipRole(role),
        active: active,
        tenantEmail: (email == null || email.isEmpty) ? null : email,
        tenantEmailSet: true,
        didInitialPrefill: true,
      );
    } else {
      // Still update email if we didn't have one yet and membership now has it.
      if ((next.tenantEmail ?? '').isEmpty && tenantMem != null) {
        final email = (tenantMem['email'] as String?)?.trim();
        if (email != null && email.isNotEmpty) {
          next = next.copyWith(tenantEmail: email, tenantEmailSet: true);
        }
      }
    }

    if (mounted) state = next;
  }

  Map<String, Object?> _buildPatchFromForm() {
    final status = state.active ? 'active' : 'disabled';
    final type = state.level.userTypeForTenantAuthUser;
    final staffRoles = state.level.staffRolesForTenantAuthUser;

    return <String, Object?>{
      'type': type, // "member" | "staff"
      'staffRoles': staffRoles, // [] or ["admin"] etc
      'status': status, // "active" | "disabled"
    };
  }

  Future<bool> save() async {
    if (_t.isEmpty || _u.isEmpty) {
      SnackService.showError('❌ Missing tenant or uid');
      return false;
    }
    if (state.saving || state.deleting) return false;

    state = state.copyWith(saving: true);

    try {
      final allUsers = ref.read(allUsersControllerProvider.notifier);
      final patch = _buildPatchFromForm();

      final res = await allUsers.hqPatchTenantUser(
        targetTenantId: _t,
        uid: _u,
        patch: patch,
      );

      return res != null;
    } catch (e, st) {
      if (kDebugMode) debugPrint('🧨 UserEditor.save failed: $e\n$st');
      SnackService.showError('❌ Failed to save: $e');
      return false;
    } finally {
      if (mounted) state = state.copyWith(saving: false);
    }
  }

  Future<bool> removeAccess() async {
    if (_t.isEmpty || _u.isEmpty) return false;
    if (state.saving || state.deleting) return false;

    state = state.copyWith(deleting: true);

    try {
      final allUsers = ref.read(allUsersControllerProvider.notifier);
      await allUsers.hqDeleteTenantUser(targetTenantId: _t, uid: _u);
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('🧨 UserEditor.removeAccess failed: $e\n$st');
      SnackService.showError('❌ Failed to remove access: $e');
      return false;
    } finally {
      if (mounted) state = state.copyWith(deleting: false);
    }
  }

  // Convenience for the UI preview card
  String get patchTypePreview => state.level.userTypeForTenantAuthUser;
  List<String> get patchRolesPreview => state.level.staffRolesForTenantAuthUser;
}
