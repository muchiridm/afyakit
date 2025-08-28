// lib/users/user_manager/extensions/user_role_x.dart

/// NOTE: 'superadmin' is handled via claims (AuthUser.isSuperAdmin),
/// not as a membership role. If you see 'superadmin' as a string, we
/// map it to an admin-like role in parsing to avoid breaking UI gates.
enum UserRole {
  admin,
  manager,
  staff,

  // New roles for multi-tenant lifecycle
  owner,
  client;

  /// Back-compat: tolerant parser with a few synonyms.
  static UserRole fromString(String input) {
    final s = input.trim().toLowerCase();
    switch (s) {
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'staff':
        return UserRole.staff;

      // New roles (safe)
      case 'owner':
      case 'tenantowner':
      case 'tenant_owner':
        return UserRole.owner;

      case 'client':
      case 'customer':
        return UserRole.client;

      // Treat superadmin as admin-like for UI gates;
      // true superadmin is still detected via claims.
      case 'superadmin':
        return UserRole.admin;

      default:
        // Fallback for unknown/legacy inputs.
        return UserRole.staff;
    }
  }

  /// Stable, backend-facing name.
  String get wire => toString().split('.').last;

  /// Back-compat: previous code may call .name directly.
  String get name => wire;
}

extension UserRoleX on UserRole {
  // ── Identity checks
  bool get isOwner => this == UserRole.owner;
  bool get isAdmin =>
      this == UserRole.admin || this == UserRole.owner; // owner is admin-like
  bool get isManager => this == UserRole.manager;
  bool get isStaff => this == UserRole.staff;
  bool get isClient => this == UserRole.client;

  // ── Capability gates (owner inherits admin)
  bool get canViewEverything => true;
  bool get canRequestStock => true;

  bool get canAccessAdminPanel => isAdmin;
  bool get canManageUsers => isAdmin;
  bool get canManageAllStores => isAdmin;

  bool get canManageSku => isAdmin || isManager;
  bool get canManageBatches => isAdmin || isManager;
  bool get canReceiveBatches => isAdmin || isManager;
  bool get canApproveIssues => isAdmin || isManager;
  bool get canDisposeStock => isAdmin || isManager;
  bool get canViewReports => true;

  bool get isViewOnly => isStaff || isClient;

  String get label => switch (this) {
    UserRole.admin => 'Admin',
    UserRole.manager => 'Manager',
    UserRole.staff => 'Staff',
    UserRole.owner => 'Owner',
    UserRole.client => 'Client',
  };

  /// Role precedence for simple comparisons/sorting
  int get level => switch (this) {
    UserRole.owner => 4,
    UserRole.admin => 3,
    UserRole.manager => 2,
    UserRole.staff => 1,
    UserRole.client => 0,
  };

  /// Who can assign what (front-end guardrails; backend is authoritative).
  bool canAssignRole(UserRole target) {
    // Owner can assign any tenant role (including promoting/demoting admins)
    if (isOwner) return true;

    // Admin cannot assign owner
    if (this == UserRole.admin) return target != UserRole.owner;

    // Manager can assign only non-elevated roles
    if (isManager) {
      return target == UserRole.manager ||
          target == UserRole.staff ||
          target == UserRole.client;
    }

    // Staff/Client cannot assign
    return false;
  }
}
