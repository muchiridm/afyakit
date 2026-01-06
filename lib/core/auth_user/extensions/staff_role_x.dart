// lib/core/auth_users/extensions/staff_role_x.dart

enum StaffRole {
  owner,
  admin,
  manager,
  staff,
  runner,
  dispatcher,
  pharmacist,
  prescriber;

  /// Strict parser with least-privilege fallback.
  static StaffRole fromString(String input) {
    final s = input.trim().toLowerCase();
    for (final r in StaffRole.values) {
      if (r.name == s) return r;
    }
    // Fallback to the lowest generic staff role
    return StaffRole.staff;
  }

  /// Nullable parser; returns null when unknown.
  static StaffRole? tryParse(String? input) {
    if (input == null) return null;
    final s = input.trim().toLowerCase();
    for (final r in StaffRole.values) {
      if (r.name == s) return r;
    }
    return null;
  }

  String get wire => toString().split('.').last;
  String get name => wire;
}

extension StaffRoleX on StaffRole {
  // ─────────────────────────────
  // Identity checks
  // ─────────────────────────────
  bool get isOwner => this == StaffRole.owner;
  bool get isAdmin => this == StaffRole.admin;
  bool get isManager => this == StaffRole.manager;
  bool get isStaff => this == StaffRole.staff;

  bool get isRunner => this == StaffRole.runner;
  bool get isDispatcher => this == StaffRole.dispatcher;

  bool get isPharmacist => this == StaffRole.pharmacist;
  bool get isDoctor => this == StaffRole.prescriber;

  // ─────────────────────────────
  // Capability gates
  // ─────────────────────────────
  bool get canAccessAdminPanel => isOwner || isAdmin || isManager;
  bool get canManageUsers => isOwner || isAdmin;
  bool get canManageAllStores => isOwner || isAdmin;

  bool get canManageSku => isOwner || isAdmin || isManager;
  bool get canManageBatches => isOwner || isAdmin || isManager;
  bool get canReceiveBatches => isOwner || isAdmin || isManager;
  bool get canApproveIssues => isOwner || isAdmin || isManager;
  bool get canDisposeStock => isOwner || isAdmin || isManager;

  // Everyone in staff ecosystem
  bool get canViewReports => true;
  bool get canRequestStock => true;

  // Owner-only governance
  bool get canManageTenantSettings => isOwner;
  bool get canManageBilling => isOwner;
  bool get canTransferOwnership => isOwner;
  bool get canExportAllData => isOwner;
  bool get canDeleteTenant => isOwner;

  // ─────────────────────────────
  // UX hint
  // ─────────────────────────────
  bool get isViewOnly => !(isOwner || isAdmin || isManager);

  // ─────────────────────────────
  // Human labels
  // ─────────────────────────────
  String get label => switch (this) {
    StaffRole.owner => 'Owner',
    StaffRole.admin => 'Admin',
    StaffRole.manager => 'Manager',
    StaffRole.staff => 'Staff',
    StaffRole.runner => 'Runner',
    StaffRole.dispatcher => 'Dispatcher',
    StaffRole.pharmacist => 'Pharmacist',
    StaffRole.prescriber => 'Doctor',
  };

  // ─────────────────────────────
  // Precedence ranking
  // ─────────────────────────────
  int get level => switch (this) {
    StaffRole.owner => 7,
    StaffRole.admin => 6,
    StaffRole.manager => 5,

    // Clinical
    StaffRole.prescriber => 4,
    StaffRole.pharmacist => 4,

    // Logistics / support
    StaffRole.dispatcher => 3,
    StaffRole.runner => 3,

    // Baseline staff
    StaffRole.staff => 1,
  };

  int compare(StaffRole other) => level.compareTo(other.level);

  // ─────────────────────────────
  // Assignment rules
  // ─────────────────────────────
  bool canAssignRole(StaffRole target) {
    if (isOwner) return true;

    if (isAdmin) {
      return switch (target) {
        StaffRole.owner || StaffRole.admin => false,
        _ => true,
      };
    }

    if (isManager) {
      return switch (target) {
        StaffRole.manager ||
        StaffRole.staff ||
        StaffRole.runner ||
        StaffRole.dispatcher ||
        StaffRole.prescriber ||
        StaffRole.pharmacist => true,
        StaffRole.owner || StaffRole.admin => false,
      };
    }

    return false;
  }

  // ─────────────────────────────
  // UI: assignable roles picker
  // ─────────────────────────────
  List<StaffRole> assignableTargets() {
    if (isOwner) return StaffRole.values;

    if (isAdmin) {
      return StaffRole.values
          .where((r) => r != StaffRole.owner && r != StaffRole.admin)
          .toList();
    }

    if (isManager) {
      return const [
        StaffRole.manager,
        StaffRole.staff,
        StaffRole.runner,
        StaffRole.dispatcher,
        StaffRole.prescriber,
        StaffRole.pharmacist,
      ];
    }

    return const [];
  }
}

/// Choose highest-precedence staff role
extension StaffRoleListX on Iterable<StaffRole> {
  StaffRole? get primaryRole {
    if (isEmpty) return null;
    return reduce((a, b) => b.level > a.level ? b : a);
  }
}
