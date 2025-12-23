// lib/core/auth_users/extensions/staff_role_x.dart

enum StaffRole {
  owner,
  admin,
  manager,
  staff,
  rider,
  doctor,
  pharmacist,
  nurse,
  dispatcher;

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
  // ── Identity checks
  bool get isOwner => this == StaffRole.owner;
  bool get isAdmin => this == StaffRole.admin;
  bool get isManager => this == StaffRole.manager;
  bool get isStaff => this == StaffRole.staff;

  bool get isRider => this == StaffRole.rider;
  bool get isDoctor => this == StaffRole.doctor;
  bool get isPharmacist => this == StaffRole.pharmacist;
  bool get isNurse => this == StaffRole.nurse;
  bool get isDispatcher => this == StaffRole.dispatcher;

  // ── Capability gates
  // Owner can do everything admin/manager can, plus governance.
  bool get canAccessAdminPanel => isOwner || isAdmin || isManager;
  bool get canManageUsers => isOwner || isAdmin;
  bool get canManageAllStores => isOwner || isAdmin;

  bool get canManageSku => isOwner || isAdmin || isManager;
  bool get canManageBatches => isOwner || isAdmin || isManager;
  bool get canReceiveBatches => isOwner || isAdmin || isManager;
  bool get canApproveIssues => isOwner || isAdmin || isManager;
  bool get canDisposeStock => isOwner || isAdmin || isManager;

  bool get canViewReports => true;
  bool get canRequestStock => true;

  // Owner-only governance
  bool get canManageTenantSettings => isOwner;
  bool get canManageBilling => isOwner;
  bool get canTransferOwnership => isOwner;
  bool get canExportAllData => isOwner;
  bool get canDeleteTenant => isOwner;

  // View-only UX hints:
  bool get isViewOnly => !(isOwner || isAdmin || isManager);

  String get label => switch (this) {
    StaffRole.owner => 'Owner',
    StaffRole.admin => 'Admin',
    StaffRole.manager => 'Manager',
    StaffRole.staff => 'Staff',
    StaffRole.rider => 'Rider',
    StaffRole.doctor => 'Doctor',
    StaffRole.pharmacist => 'Pharmacist',
    StaffRole.nurse => 'Nurse',
    StaffRole.dispatcher => 'Dispatcher',
  };

  /// Role precedence for sorting/comparison
  int get level => switch (this) {
    StaffRole.owner => 6,
    StaffRole.admin => 5,
    StaffRole.manager => 4,
    StaffRole.staff => 3,
    StaffRole.doctor => 3,
    StaffRole.pharmacist => 3,
    StaffRole.nurse => 2,
    StaffRole.rider => 2,
    StaffRole.dispatcher => 2,
  };

  int compare(StaffRole other) => level.compareTo(other.level);

  /// Who can assign what (front-end guardrails; backend authoritative).
  bool canAssignRole(StaffRole target) {
    if (isOwner) return true; // full control

    // Admins can assign operational roles, but:
    // - cannot assign OWNER
    // - cannot assign ADMIN (only owners can appoint admins)
    if (isAdmin) {
      return switch (target) {
        StaffRole.owner || StaffRole.admin => false,
        _ => true,
      };
    }

    if (isManager) {
      // Managers can assign operational/clinical roles but not governance.
      return switch (target) {
        StaffRole.manager ||
        StaffRole.staff ||
        StaffRole.rider ||
        StaffRole.dispatcher ||
        StaffRole.doctor ||
        StaffRole.pharmacist ||
        StaffRole.nurse => true,
        StaffRole.owner || StaffRole.admin => false,
      };
    }

    return false;
  }

  /// Convenience for UIs (role pickers, etc.)
  List<StaffRole> assignableTargets() {
    if (isOwner) {
      return StaffRole.values;
    }
    if (isAdmin) {
      // Everything except owner/admin is fair game for admins.
      return StaffRole.values
          .where((r) => r != StaffRole.owner && r != StaffRole.admin)
          .toList();
    }
    if (isManager) {
      return const [
        StaffRole.manager,
        StaffRole.staff,
        StaffRole.rider,
        StaffRole.dispatcher,
        StaffRole.doctor,
        StaffRole.pharmacist,
        StaffRole.nurse,
      ];
    }
    return const [];
  }
}
