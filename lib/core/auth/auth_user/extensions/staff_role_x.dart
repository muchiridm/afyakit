// lib/core/auth_users/extensions/staff_role_x.dart

/// Staff roles inside a tenant.
///
/// Notes:
/// - Parsing is strict but safe (least privilege fallback).
/// - `wire` uses enum `.name` (stable lowercase string).
enum StaffRole {
  owner,
  admin,
  manager,
  staff,
  runner,
  dispatcher,
  pharmacist,
  prescriber;

  // ─────────────────────────────────────────────
  // Parsing
  // ─────────────────────────────────────────────

  /// Safe parse with least-privilege fallback.
  /// Unknown → [StaffRole.staff].
  static StaffRole fromString(String? input) {
    final s = (input ?? '').trim().toLowerCase();
    for (final r in StaffRole.values) {
      if (r.name == s) return r;
    }
    return StaffRole.staff;
  }

  /// Nullable parse; returns null when unknown/empty.
  static StaffRole? tryParse(String? input) {
    final s = (input ?? '').trim().toLowerCase();
    if (s.isEmpty) return null;
    for (final r in StaffRole.values) {
      if (r.name == s) return r;
    }
    return null;
  }

  // ─────────────────────────────────────────────
  // Wire / UI helpers
  // ─────────────────────────────────────────────

  /// Backend-facing string value (lowercase).
  String get wire => name;

  /// Human-friendly label.
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

  // ─────────────────────────────────────────────
  // Precedence ranking
  // ─────────────────────────────────────────────

  /// Higher = more powerful (rough ordering for UI + gates).
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

    // Baseline
    StaffRole.staff => 1,
  };

  int compareTo(StaffRole other) => level.compareTo(other.level);

  // ─────────────────────────────────────────────
  // Capability gates
  // ─────────────────────────────────────────────

  bool get isOwner => this == StaffRole.owner;
  bool get isAdmin => this == StaffRole.admin;
  bool get isManager => this == StaffRole.manager;

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

  /// UX hint: anyone not (owner/admin/manager) is effectively view-only.
  bool get isViewOnly => !(isOwner || isAdmin || isManager);

  // ─────────────────────────────────────────────
  // Assignment rules
  // ─────────────────────────────────────────────

  bool canAssignRole(StaffRole target) {
    if (isOwner) return true;

    if (isAdmin) {
      return target != StaffRole.owner && target != StaffRole.admin;
    }

    if (isManager) {
      return switch (target) {
        StaffRole.owner || StaffRole.admin => false,
        _ => true,
      };
    }

    return false;
  }

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

/// Choose highest-precedence staff role.
extension StaffRoleListX on Iterable<StaffRole> {
  StaffRole? get primaryRole {
    if (isEmpty) return null;
    return reduce((a, b) => b.level > a.level ? b : a);
  }
}
