// lib/features/hq/users/all_users/controllers/user_editor_controller.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/hq/users/all_users/all_user_model.dart';
import 'package:afyakit/features/hq/users/all_users/all_users_service.dart';
import 'package:afyakit/features/hq/users/all_users/controllers/all_users_controller.dart';
import 'package:afyakit/shared/services/snack_service.dart';

// ─────────────────────────────────────────────
// Application access levels
// ─────────────────────────────────────────────

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

  /// Retained for compatibility with existing UI.
  /// This is descriptive only, not a tenant-wide role.
  String get membershipRole {
    return this == AccessLevel.member ? 'client' : name;
  }

  /// Canonical application-scoped staff roles.
  ///
  /// An empty list means ordinary app membership.
  List<String> get staffRolesForApp {
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

  /// Compatibility getter for the existing UI.
  ///
  /// Never send this through the tenant-wide PATCH.
  List<String> get staffRolesForTenantAuthUser => staffRolesForApp;

  static AccessLevel fromMembershipRole(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'owner':
        return AccessLevel.owner;
      case 'admin':
        return AccessLevel.admin;
      case 'manager':
      case 'staff':
        return AccessLevel.manager;
      default:
        return AccessLevel.member;
    }
  }
}

// ─────────────────────────────────────────────
// Provider arguments
// ─────────────────────────────────────────────

@immutable
class UserEditorArgs {
  const UserEditorArgs({
    required this.tenantId,
    required this.uid,
    this.initialUser,
    this.appId,
  });

  final String tenantId;
  final String uid;
  final String? appId;
  final AllUser? initialUser;

  String get cleanTenantId => tenantId.trim();
  String get cleanUid => uid.trim();
  String get cleanAppId => (appId ?? '').trim().toLowerCase();

  @override
  bool operator ==(Object other) {
    return other is UserEditorArgs &&
        other.cleanTenantId == cleanTenantId &&
        other.cleanUid == cleanUid &&
        other.cleanAppId == cleanAppId;
  }

  @override
  int get hashCode => Object.hash(cleanTenantId, cleanUid, cleanAppId);
}

// ─────────────────────────────────────────────
// State
// ─────────────────────────────────────────────

@immutable
class UserEditorState {
  const UserEditorState({
    required this.tenantId,
    required this.uid,
    this.appId = '',
    this.initialUser,
    this.loadingMemberships = false,
    this.saving = false,
    this.deleting = false,
    this.didInitialPrefill = false,
    this.level = AccessLevel.member,
    this.active = false,
    this.tenantEmail,
    this.hasAccess = false,
    this.allMemberships = const <String, AllUserMembership>{},
  });

  final String tenantId;
  final String uid;

  /// Application currently being edited.
  final String appId;

  final AllUser? initialUser;

  final bool loadingMemberships;
  final bool saving;
  final bool deleting;
  final bool didInitialPrefill;

  /// Selected application's staff role.
  final AccessLevel level;

  /// Selected application's membership status.
  /// Not the tenant account status.
  final bool active;

  final String? tenantEmail;

  /// Whether the tenant auth_user record exists.
  final bool hasAccess;

  /// tenantId -> tenant membership, including app data.
  final Map<String, AllUserMembership> allMemberships;

  bool get hasSelectedApp => appId.trim().isNotEmpty;

  AllUserMembership? get tenantMembership => allMemberships[tenantId];

  bool get tenantAccountActive => tenantMembership?.active ?? false;

  bool get appMembershipExists =>
      tenantMembership?.hasAppMembership(appId) ?? false;

  UserEditorState copyWith({
    String? appId,
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
      appId: appId ?? this.appId,
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

// ─────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────

final userEditorControllerProvider = StateNotifierProvider.autoDispose
    .family<UserEditorController, UserEditorState, UserEditorArgs>((ref, args) {
      return UserEditorController(ref, args);
    });

// ─────────────────────────────────────────────
// Controller
// ─────────────────────────────────────────────

class UserEditorController extends StateNotifier<UserEditorState> {
  UserEditorController(this.ref, UserEditorArgs args)
    : super(
        UserEditorState(
          tenantId: args.cleanTenantId,
          uid: args.cleanUid,
          appId: args.cleanAppId,
          initialUser: args.initialUser,
        ),
      ) {
    // ignore: discarded_futures
    init();
  }

  final Ref ref;

  String get _tenantId => state.tenantId.trim();
  String get _uid => state.uid.trim();
  String get _appId => state.appId.trim().toLowerCase();

  // ───────────────────────────────────────────
  // Initialisation
  // ───────────────────────────────────────────

  Future<void> init() async {
    if (_tenantId.isEmpty || _uid.isEmpty || !mounted) {
      return;
    }

    final initialMemberships = _membershipsFromInitialUser();

    if (initialMemberships.isNotEmpty) {
      _applyMembershipsToState(initialMemberships, allowPrefill: true);
    }

    // Fetch the authoritative membership state.
    await refreshMemberships(force: true);
  }

  // ───────────────────────────────────────────
  // Application selection
  // ───────────────────────────────────────────

  /// Called by the application selector in the UI.
  ///
  /// The UI must supply an app registered under
  /// the selected tenant.
  void setAppId(String appId) {
    if (!mounted || state.saving || state.deleting) {
      return;
    }

    final clean = appId.trim().toLowerCase();

    if (clean.isNotEmpty &&
        !RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(clean)) {
      SnackService.showError('Invalid application ID');
      return;
    }

    if (clean == _appId) return;

    state = state.copyWith(
      appId: clean,
      level: AccessLevel.member,
      active: false,
      didInitialPrefill: false,
    );

    _prefillSelectedApp();
  }

  void setAccessLevel(AccessLevel level) {
    if (!mounted || state.saving || state.deleting) {
      return;
    }

    state = state.copyWith(level: level);
  }

  /// Enable/disable only the selected application.
  void setActive(bool value) {
    if (!mounted || state.saving || state.deleting) {
      return;
    }

    state = state.copyWith(active: value);
  }

  // ───────────────────────────────────────────
  // Membership loading
  // ───────────────────────────────────────────

  Future<void> refreshMemberships({bool force = true}) async {
    if (_tenantId.isEmpty || _uid.isEmpty || !mounted) {
      return;
    }

    state = state.copyWith(loadingMemberships: true);

    try {
      final allUsers = ref.read(allUsersControllerProvider.notifier);

      if (force) {
        await allUsers.refreshMembershipsForUid(_uid);
        if (!mounted) return;
      }

      final memberships = await allUsers.fetchMemberships(_uid);

      if (!mounted) return;

      _applyMembershipsToState(memberships, allowPrefill: true);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('UserEditor.refreshMemberships failed: $e\n$st');
      }

      if (mounted) {
        SnackService.showError('Failed to refresh memberships: $e');
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

    final result = <String, AllUserMembership>{};

    for (final membership in user.memberships) {
      final tenantId = membership.tenantId.trim();

      if (tenantId.isNotEmpty) {
        result[tenantId] = membership;
      }
    }

    return result;
  }

  void _applyMembershipsToState(
    Map<String, AllUserMembership> memberships, {
    required bool allowPrefill,
  }) {
    if (!mounted) return;

    final tenantMembership = memberships[_tenantId];

    final email = tenantMembership?.email?.trim();

    state = state.copyWith(
      hasAccess: tenantMembership != null,
      allMemberships: memberships,
      tenantEmail: email == null || email.isEmpty ? null : email,
      tenantEmailSet: true,
    );

    if (allowPrefill) {
      _prefillSelectedApp();
    }
  }

  void _prefillSelectedApp() {
    if (!mounted || _appId.isEmpty) return;

    final tenantMembership = state.allMemberships[_tenantId];

    final appActive = tenantMembership?.hasActiveAppMembership(_appId) ?? false;

    final role = tenantMembership == null
        ? AccessLevel.member
        : AccessLevel.fromMembershipRole(
            tenantMembership.accessLevelForApp(_appId),
          );

    state = state.copyWith(
      level: role,
      active: appActive,
      didInitialPrefill: true,
    );
  }

  // ───────────────────────────────────────────
  // Save selected app access
  // ───────────────────────────────────────────

  Future<bool> save() async {
    if (!mounted || state.saving || state.deleting) {
      return false;
    }

    if (_tenantId.isEmpty || _uid.isEmpty) {
      SnackService.showError('Missing tenant or user ID');
      return false;
    }

    if (_appId.isEmpty) {
      SnackService.showError('Select an application before saving.');
      return false;
    }

    if (state.loadingMemberships) {
      SnackService.showError('Wait for memberships to finish loading.');
      return false;
    }

    if (!state.hasAccess) {
      SnackService.showError('User does not have a tenant account.');
      return false;
    }

    if (state.active && !state.tenantAccountActive) {
      SnackService.showError(
        'Enable the tenant account before '
        'enabling application access.',
      );
      return false;
    }

    final targetActive = state.active;
    final targetRoles = targetActive
        ? state.level.staffRolesForApp
        : const <String>[];

    final current = state.tenantMembership;
    final wasActive = current?.hasActiveAppMembership(_appId) ?? false;
    final oldRoles = current?.rolesForApp(_appId) ?? const <String>[];

    state = state.copyWith(saving: true);

    var changedMembership = false;
    var changedRoles = false;

    try {
      final svc = await ref.read(allUsersServiceProvider.future);

      if (targetActive) {
        // Staff roles require active app membership.
        if (!wasActive) {
          await svc.setAppMembership(
            tenantId: _tenantId,
            uid: _uid,
            appId: _appId,
            active: true,
          );
          changedMembership = true;
        }

        if (!listEquals(oldRoles, targetRoles)) {
          await svc.setAppStaffRoles(
            tenantId: _tenantId,
            uid: _uid,
            appId: _appId,
            staffRoles: targetRoles,
          );
          changedRoles = true;
        }
      } else if (wasActive || oldRoles.isNotEmpty) {
        // Disabling an app also clears its staff roles.
        await svc.setAppMembership(
          tenantId: _tenantId,
          uid: _uid,
          appId: _appId,
          active: false,
        );
        changedMembership = true;
      }

      if (!mounted) return true;

      await refreshMemberships(force: true);

      if (kDebugMode) {
        debugPrint(
          'UserEditor.save: '
          'tenant=$_tenantId '
          'app=$_appId '
          'uid=$_uid '
          'active=$targetActive '
          'roles=$targetRoles '
          'membershipChanged=$changedMembership '
          'rolesChanged=$changedRoles',
        );
      }

      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('UserEditor.save failed: $e\n$st');
      }

      if (mounted) {
        SnackService.showError(
          'Application access could not be fully '
          'saved. Refresh to verify the current '
          'permissions. $e',
        );

        // The first API operation may have succeeded.
        // Reload rather than pretending it was rolled back.
        await refreshMemberships(force: true);
      }

      return false;
    } finally {
      if (mounted) {
        state = state.copyWith(saving: false);
      }
    }
  }

  // ───────────────────────────────────────────
  // Disable selected app access
  // ───────────────────────────────────────────

  /// Does not delete the tenant auth_user.
  ///
  /// Does not affect other applications.
  Future<bool> removeAccess() async {
    if (!mounted || state.saving || state.deleting) {
      return false;
    }

    if (_tenantId.isEmpty || _uid.isEmpty || _appId.isEmpty) {
      SnackService.showError('Select a tenant, user and application.');
      return false;
    }

    state = state.copyWith(deleting: true);

    try {
      final svc = await ref.read(allUsersServiceProvider.future);

      await svc.setAppMembership(
        tenantId: _tenantId,
        uid: _uid,
        appId: _appId,
        active: false,
      );

      if (!mounted) return true;

      state = state.copyWith(active: false, level: AccessLevel.member);

      await refreshMemberships(force: true);

      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('UserEditor.removeAccess failed: $e\n$st');
      }

      if (mounted) {
        SnackService.showError('Failed to disable app access: $e');
        await refreshMemberships(force: true);
      }

      return false;
    } finally {
      if (mounted) {
        state = state.copyWith(deleting: false);
      }
    }
  }

  // ───────────────────────────────────────────
  // Preview
  // ───────────────────────────────────────────

  List<String> get patchRolesPreview =>
      state.active ? state.level.staffRolesForApp : const <String>[];
}
