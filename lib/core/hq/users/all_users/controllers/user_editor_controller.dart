// lib/hq/users/all_users/controllers/user_editor_controller.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/hq/users/all_users/all_user_model.dart';
import 'package:afyakit/core/hq/users/all_users/controllers/all_users_controller.dart';
import 'package:afyakit/shared/services/snack_service.dart';

/// UI access levels.
///
/// Backend rule:
/// - Staff access is driven ONLY by staffRoles.
/// - Do NOT send legacy `type`.
enum AccessLevel {
  member,
  manager,
  admin,
  owner;

  String get label {
    switch (this) {
      case AccessLevel.member:
        return 'Member';
      case AccessLevel.manager:
        return 'Manager';
      case AccessLevel.admin:
        return 'Admin';
      case AccessLevel.owner:
        return 'Owner';
    }
  }

  String get membershipRole {
    switch (this) {
      case AccessLevel.member:
        return 'client';
      case AccessLevel.manager:
        return 'manager';
      case AccessLevel.admin:
        return 'admin';
      case AccessLevel.owner:
        return 'owner';
    }
  }

  /// Tenant auth_user patch staffRoles.
  ///
  /// [] means normal member/client.
  /// manager/admin/owner are explicit staff roles.
  List<String> get staffRolesForTenantAuthUser {
    switch (this) {
      case AccessLevel.member:
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

      // Old data fallback. Since plain staff is no longer a real assignable
      // access level, map old "staff" display data to Manager for now.
      case 'staff':
        return AccessLevel.manager;

      case 'client':
      case 'member':
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

  String get cleanTenantId => targetTenantId.trim();
  String get cleanUid => uid.trim();

  /// Critical:
  /// This object is used as a Riverpod `.family` key.
  /// Without equality, every rebuild creates a new provider instance and
  /// the Access Level UI appears non-responsive because state resets.
  @override
  bool operator ==(Object other) {
    return other is UserEditorArgs &&
        other.cleanTenantId == cleanTenantId &&
        other.cleanUid == cleanUid;
  }

  @override
  int get hashCode => Object.hash(cleanTenantId, cleanUid);
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
    this.allMemberships = const <String, AllUserMembership>{},
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

  /// tenantId -> membership.
  final Map<String, AllUserMembership> allMemberships;

  UserEditorState copyWith({
    bool? loadingMemberships,
    bool? saving,
    bool? deleting,
    bool? didInitialPrefill,
    AccessLevel? level,
    bool? active,
    String? tenantEmail,
    bool tenantEmailSet = false,
    bool? hasAccess,
    Map<String, AllUserMembership>? allMemberships,
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
      allMemberships: allMemberships ?? this.allMemberships,
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
          targetTenantId: args.cleanTenantId,
          uid: args.cleanUid,
          initialUser: args.initialUser,
        ),
      ) {
    // ignore: discarded_futures
    init();
  }

  final Ref ref;

  String get _t => state.targetTenantId.trim();
  String get _u => state.uid.trim();

  Future<void> init() async {
    if (_t.isEmpty || _u.isEmpty) return;

    final initialMemberships = _membershipsFromInitialUser();

    if (initialMemberships.isNotEmpty) {
      _applyMembershipsToState(initialMemberships, allowPrefill: true);
      return;
    }

    await refreshMemberships(force: false);
  }

  void setAccessLevel(AccessLevel level) {
    if (!mounted) return;
    state = state.copyWith(level: level);
  }

  void setActive(bool v) {
    if (!mounted) return;
    state = state.copyWith(active: v);
  }

  Future<void> refreshMemberships({bool force = true}) async {
    if (_t.isEmpty || _u.isEmpty) return;
    if (!mounted) return;

    state = state.copyWith(loadingMemberships: true);

    try {
      final allUsers = ref.read(allUsersControllerProvider.notifier);

      final Map<String, AllUserMembership> mems;

      if (force) {
        await allUsers.refreshMembershipsForUid(_u);
        if (!mounted) return;

        mems = await allUsers.fetchMemberships(_u);
        if (!mounted) return;
      } else {
        mems = await allUsers.fetchMemberships(_u);
        if (!mounted) return;
      }

      _applyMembershipsToState(mems, allowPrefill: !state.didInitialPrefill);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('🧨 UserEditor.refreshMemberships failed: $e\n$st');
      }

      if (mounted) {
        SnackService.showError('❌ Failed to refresh memberships: $e');
      }
    } finally {
      if (mounted) {
        state = state.copyWith(loadingMemberships: false);
      }
    }
  }

  Map<String, AllUserMembership> _membershipsFromInitialUser() {
    final user = state.initialUser;

    if (user == null || user.memberships.isEmpty) {
      return const <String, AllUserMembership>{};
    }

    final out = <String, AllUserMembership>{};

    for (final membership in user.memberships) {
      final tenantId = membership.tenantId.trim();
      if (tenantId.isEmpty) continue;

      out[tenantId] = membership;
    }

    return out;
  }

  void _applyMembershipsToState(
    Map<String, AllUserMembership> mems, {
    required bool allowPrefill,
  }) {
    if (!mounted) return;

    final tenantMem = mems[_t];
    final hasAccess = tenantMem != null;

    var next = state.copyWith(hasAccess: hasAccess, allMemberships: mems);

    if (allowPrefill && !next.didInitialPrefill && tenantMem != null) {
      final email = tenantMem.email?.trim();

      next = next.copyWith(
        level: AccessLevel.fromMembershipRole(tenantMem.role),
        active: tenantMem.active,
        tenantEmail: email == null || email.isEmpty ? null : email,
        tenantEmailSet: true,
        didInitialPrefill: true,
      );
    } else if ((next.tenantEmail ?? '').isEmpty && tenantMem != null) {
      final email = tenantMem.email?.trim();

      if (email != null && email.isNotEmpty) {
        next = next.copyWith(tenantEmail: email, tenantEmailSet: true);
      }
    }

    state = next;
  }

  Map<String, Object?> _buildPatchFromForm() {
    final status = state.active ? 'active' : 'disabled';
    final staffRoles = state.level.staffRolesForTenantAuthUser;

    return <String, Object?>{'staffRoles': staffRoles, 'status': status};
  }

  void _patchLocalTargetMembership() {
    if (!mounted) return;

    final current = state.allMemberships[_t];

    final updated = AllUserMembership(
      tenantId: _t,
      role: state.level.membershipRole,
      active: state.active,
      status: state.active ? 'active' : 'disabled',
      email: state.tenantEmail ?? current?.email,
    );

    final nextMems = Map<String, AllUserMembership>.from(state.allMemberships);
    nextMems[_t] = updated;

    state = state.copyWith(
      hasAccess: true,
      allMemberships: nextMems,
      didInitialPrefill: true,
    );
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

      if (res == null) return false;
      if (!mounted) return true;

      // Do not immediately call /api/users/:uid/memberships here.
      // Backend now should not revoke tokens for role changes, but this still
      // avoids unnecessary racey follow-up calls after a successful PATCH.
      _patchLocalTargetMembership();

      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('🧨 UserEditor.save failed: $e\n$st');
      }

      if (mounted) {
        SnackService.showError('❌ Failed to save: $e');
      }

      return false;
    } finally {
      if (mounted) {
        state = state.copyWith(saving: false);
      }
    }
  }

  Future<bool> removeAccess() async {
    if (_t.isEmpty || _u.isEmpty) return false;
    if (state.saving || state.deleting) return false;

    state = state.copyWith(deleting: true);

    try {
      final allUsers = ref.read(allUsersControllerProvider.notifier);

      await allUsers.hqDeleteTenantUser(targetTenantId: _t, uid: _u);

      if (!mounted) return true;

      final nextMems = Map<String, AllUserMembership>.from(state.allMemberships)
        ..remove(_t);

      _applyMembershipsToState(nextMems, allowPrefill: false);

      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('🧨 UserEditor.removeAccess failed: $e\n$st');
      }

      if (mounted) {
        SnackService.showError('❌ Failed to remove access: $e');
      }

      return false;
    } finally {
      if (mounted) {
        state = state.copyWith(deleting: false);
      }
    }
  }

  List<String> get patchRolesPreview => state.level.staffRolesForTenantAuthUser;
}
