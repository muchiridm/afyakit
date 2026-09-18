// lib/hq/users/all_users/controllers/user_editor_controller.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/hq/users/all_users/all_user_model.dart';
import 'package:afyakit/features/hq/users/all_users/controllers/all_users_controller.dart';
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

  /// Tenant auth-user patch staffRoles.
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
    final role = (roleRaw ?? '').trim().toLowerCase();

    switch (role) {
      case 'owner':
        return AccessLevel.owner;

      case 'admin':
        return AccessLevel.admin;

      case 'manager':
        return AccessLevel.manager;

      // Historical display fallback only.
      // "staff" is no longer an assignable access level.
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
    required this.tenantId,
    required this.uid,
    this.initialUser,
  });

  final String tenantId;
  final String uid;
  final AllUser? initialUser;

  String get cleanTenantId => tenantId.trim();

  String get cleanUid => uid.trim();

  /// Used as a Riverpod `.family` key.
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
    required this.tenantId,
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

  final String tenantId;
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
      tenantId: tenantId,
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
          tenantId: args.cleanTenantId,
          uid: args.cleanUid,
          initialUser: args.initialUser,
        ),
      ) {
    // ignore: discarded_futures
    init();
  }

  final Ref ref;

  String get _tenantId => state.tenantId.trim();

  String get _uid => state.uid.trim();

  Future<void> init() async {
    if (_tenantId.isEmpty || _uid.isEmpty) {
      return;
    }

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

  void setActive(bool value) {
    if (!mounted) return;

    state = state.copyWith(active: value);
  }

  Future<void> refreshMemberships({bool force = true}) async {
    if (_tenantId.isEmpty || _uid.isEmpty || !mounted) {
      return;
    }

    state = state.copyWith(loadingMemberships: true);

    try {
      final allUsers = ref.read(allUsersControllerProvider.notifier);

      final Map<String, AllUserMembership> memberships;

      if (force) {
        await allUsers.refreshMembershipsForUid(_uid);

        if (!mounted) return;

        memberships = await allUsers.fetchMemberships(_uid);

        if (!mounted) return;
      } else {
        memberships = await allUsers.fetchMemberships(_uid);

        if (!mounted) return;
      }

      _applyMembershipsToState(
        memberships,
        allowPrefill: !state.didInitialPrefill,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '🧨 UserEditor.refreshMemberships '
          'failed: $e\n$st',
        );
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

      if (tenantId.isEmpty) {
        continue;
      }

      out[tenantId] = membership;
    }

    return out;
  }

  void _applyMembershipsToState(
    Map<String, AllUserMembership> memberships, {
    required bool allowPrefill,
  }) {
    if (!mounted) return;

    final tenantMembership = memberships[_tenantId];

    final hasAccess = tenantMembership != null;

    var next = state.copyWith(
      hasAccess: hasAccess,
      allMemberships: memberships,
    );

    if (allowPrefill && !next.didInitialPrefill && tenantMembership != null) {
      final email = tenantMembership.email?.trim();

      next = next.copyWith(
        level: AccessLevel.fromMembershipRole(tenantMembership.role),
        active: tenantMembership.active,
        tenantEmail: email == null || email.isEmpty ? null : email,
        tenantEmailSet: true,
        didInitialPrefill: true,
      );
    } else if ((next.tenantEmail ?? '').isEmpty && tenantMembership != null) {
      final email = tenantMembership.email?.trim();

      if (email != null && email.isNotEmpty) {
        next = next.copyWith(tenantEmail: email, tenantEmailSet: true);
      }
    }

    state = next;
  }

  Map<String, Object?> _buildPatchFromForm() {
    return <String, Object?>{
      'staffRoles': state.level.staffRolesForTenantAuthUser,
      'status': state.active ? 'active' : 'disabled',
    };
  }

  void _patchLocalTargetMembership() {
    if (!mounted) return;

    final current = state.allMemberships[_tenantId];

    final updated = AllUserMembership(
      tenantId: _tenantId,
      role: state.level.membershipRole,
      active: state.active,
      status: state.active ? 'active' : 'disabled',
      email: state.tenantEmail ?? current?.email,
    );

    final nextMemberships = Map<String, AllUserMembership>.from(
      state.allMemberships,
    );

    nextMemberships[_tenantId] = updated;

    state = state.copyWith(
      hasAccess: true,
      allMemberships: nextMemberships,
      didInitialPrefill: true,
    );
  }

  Future<bool> save() async {
    if (_tenantId.isEmpty || _uid.isEmpty) {
      SnackService.showError('❌ Missing tenant or uid');

      return false;
    }

    if (state.saving || state.deleting) {
      return false;
    }

    state = state.copyWith(saving: true);

    try {
      final allUsers = ref.read(allUsersControllerProvider.notifier);

      final patch = _buildPatchFromForm();

      final result = await allUsers.updateTenantUser(
        tenantId: _tenantId,
        uid: _uid,
        patch: patch,
      );

      if (result == null) {
        return false;
      }

      if (!mounted) {
        return true;
      }

      _patchLocalTargetMembership();

      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '🧨 UserEditor.save failed: '
          '$e\n$st',
        );
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
    if (_tenantId.isEmpty || _uid.isEmpty) {
      return false;
    }

    if (state.saving || state.deleting) {
      return false;
    }

    state = state.copyWith(deleting: true);

    try {
      final allUsers = ref.read(allUsersControllerProvider.notifier);

      await allUsers.deleteTenantUser(tenantId: _tenantId, uid: _uid);

      if (!mounted) {
        return true;
      }

      final nextMemberships = Map<String, AllUserMembership>.from(
        state.allMemberships,
      )..remove(_tenantId);

      _applyMembershipsToState(nextMemberships, allowPrefill: false);

      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '🧨 UserEditor.removeAccess '
          'failed: $e\n$st',
        );
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
