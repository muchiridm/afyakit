// lib/core/auth_users/extensions/user_role_x.dart

/// Tenant-scoped roles. Keep this list minimal & ordered by authority.
enum UserRole {
  owner,
  admin,
  manager,
  staff,
  client;

  /// Strict parser with least-privilege fallback.
  static UserRole fromString(String input) {
    final s = input.trim().toLowerCase();
    for (final r in UserRole.values) {
      if (r.name == s) return r;
    }
    return UserRole.client;
  }

  /// Nullable parser; returns null when unknown.
  static UserRole? tryParse(String? input) {
    if (input == null) return null;
    final s = input.trim().toLowerCase();
    for (final r in UserRole.values) {
      if (r.name == s) return r;
    }
    return null;
  }

  /// Stable, backend-facing name.
  String get wire => toString().split('.').last;

  /// Back-compat convenience (same as [wire]).
  String get name => wire;
}

extension UserRoleX on UserRole {
  // ── Identity checks
  bool get isOwner => this == UserRole.owner;
  // Owner is considered admin-like for app permissions.
  bool get isAdmin => this == UserRole.admin || this == UserRole.owner;
  bool get isManager => this == UserRole.manager;
  bool get isStaff => this == UserRole.staff;
  bool get isClient => this == UserRole.client;

  // ── Capability gates (owner inherits admin)
  bool get canAccessAdminPanel => isAdmin;
  bool get canManageUsers => isAdmin;
  bool get canManageAllStores => isAdmin;

  bool get canManageSku => isAdmin || isManager;
  bool get canManageBatches => isAdmin || isManager;
  bool get canReceiveBatches => isAdmin || isManager;
  bool get canApproveIssues => isAdmin || isManager;
  bool get canDisposeStock => isAdmin || isManager;

  bool get canViewReports => true;
  bool get canRequestStock => true;

  // Owner-only governance (not granted to plain admins)
  bool get canManageTenantSettings => isOwner;
  bool get canManageBilling => isOwner;
  bool get canTransferOwnership => isOwner;
  bool get canExportAllData => isOwner;
  bool get canDeleteTenant => isOwner;

  // View-only UX hints (adjust if staff should edit)
  bool get isViewOnly => isStaff || isClient;

  String get label => switch (this) {
    UserRole.owner => 'Owner',
    UserRole.admin => 'Admin',
    UserRole.manager => 'Manager',
    UserRole.staff => 'Staff',
    UserRole.client => 'Client',
  };

  /// Role precedence for sorting/comparison
  int get level => switch (this) {
    UserRole.owner => 4,
    UserRole.admin => 3,
    UserRole.manager => 2,
    UserRole.staff => 1,
    UserRole.client => 0,
  };

  /// Simple comparator based on [level].
  int compare(UserRole other) => level.compareTo(other.level);

  /// Who can assign what (front-end guardrails; backend authoritative).
  bool canAssignRole(UserRole target) {
    if (isOwner) return true; // full control
    if (isAdmin) return target != UserRole.owner;
    if (isManager) {
      return target == UserRole.manager ||
          target == UserRole.staff ||
          target == UserRole.client;
    }
    return false;
  }

  /// Convenience for UIs (role pickers, etc.)
  List<UserRole> assignableTargets() {
    if (isOwner) return UserRole.values;
    if (isAdmin) {
      return const [
        UserRole.admin,
        UserRole.manager,
        UserRole.staff,
        UserRole.client,
      ];
    }
    if (isManager) {
      return const [UserRole.manager, UserRole.staff, UserRole.client];
    }
    return const [];
  }
}
