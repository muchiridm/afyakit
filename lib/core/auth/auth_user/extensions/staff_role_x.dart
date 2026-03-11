// lib/core/auth_users/extensions/staff_role_x.dart
//
// ✅ SINGLE SOURCE OF TRUTH:
//   role -> capabilities mapping lives here.
// ✅ No back-compat getters.
// ✅ Keep parsing, UI labels, precedence, assignment rules.
// ✅ Extensions provide:
//   - primaryRole
//   - capability union
//   - has/hasAny/hasAll for role lists

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
  // Wire / UI
  // ─────────────────────────────────────────────

  String get wire => name;

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
  // Precedence (UI tiering)
  // ─────────────────────────────────────────────

  /// Higher = more powerful (rough ordering for UI + "mode" tiering).
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
  // Assignment rules (role-based, not capability-based)
  // ─────────────────────────────────────────────

  bool canAssignRole(StaffRole target) {
    switch (this) {
      case StaffRole.owner:
        return true;

      case StaffRole.admin:
        return target != StaffRole.owner && target != StaffRole.admin;

      case StaffRole.manager:
        return switch (target) {
          StaffRole.owner || StaffRole.admin => false,
          _ => true,
        };

      default:
        return false;
    }
  }

  List<StaffRole> assignableTargets() {
    switch (this) {
      case StaffRole.owner:
        return StaffRole.values;

      case StaffRole.admin:
        return StaffRole.values
            .where((r) => r != StaffRole.owner && r != StaffRole.admin)
            .toList(growable: false);

      case StaffRole.manager:
        return const [
          StaffRole.manager,
          StaffRole.staff,
          StaffRole.runner,
          StaffRole.dispatcher,
          StaffRole.prescriber,
          StaffRole.pharmacist,
        ];

      default:
        return const [];
    }
  }

  // ─────────────────────────────────────────────
  // Capability model (THE ONLY PERMISSION TRUTH)
  // ─────────────────────────────────────────────

  bool has(StaffCapability cap) => capabilities.contains(cap);

  Set<StaffCapability> get capabilities => StaffRoleCapabilities.of(this);
}

/// Capability tokens (not a “mode” enum).
/// These keep UI + gates DRY and consistent.
enum StaffCapability {
  // Admin / governance
  accessAdminPanel,
  manageUsers,
  manageAllStores,

  manageTenantSettings,
  manageBilling,
  transferOwnership,
  exportAllData,
  deleteTenant,

  // Inventory
  manageSku,
  manageBatches,
  receiveBatches,

  // Issues / stock movement
  approveIssues,
  disposeStock,
  requestStock,

  // Reports
  viewReports,

  // Retail / Zoho sales docs
  manageSalesDocs,
}

/// Single source of truth: role → capabilities.
abstract final class StaffRoleCapabilities {
  static Set<StaffCapability> of(StaffRole role) {
    switch (role) {
      case StaffRole.owner:
        return const {
          // Governance
          StaffCapability.accessAdminPanel,
          StaffCapability.manageUsers,
          StaffCapability.manageAllStores,
          StaffCapability.manageTenantSettings,
          StaffCapability.manageBilling,
          StaffCapability.transferOwnership,
          StaffCapability.exportAllData,
          StaffCapability.deleteTenant,

          // Inventory
          StaffCapability.manageSku,
          StaffCapability.manageBatches,
          StaffCapability.receiveBatches,

          // Issues
          StaffCapability.approveIssues,
          StaffCapability.disposeStock,
          StaffCapability.requestStock,

          // Reports
          StaffCapability.viewReports,

          // Retail
          StaffCapability.manageSalesDocs,
        };

      case StaffRole.admin:
        return const {
          // Admin
          StaffCapability.accessAdminPanel,
          StaffCapability.manageUsers,
          StaffCapability.manageAllStores,
          StaffCapability.exportAllData,

          // Inventory
          StaffCapability.manageSku,
          StaffCapability.manageBatches,
          StaffCapability.receiveBatches,

          // Issues
          StaffCapability.approveIssues,
          StaffCapability.disposeStock,
          StaffCapability.requestStock,

          // Reports
          StaffCapability.viewReports,

          // Retail
          StaffCapability.manageSalesDocs,
        };

      case StaffRole.manager:
        return const {
          // Admin-ish
          StaffCapability.accessAdminPanel,

          // Inventory
          StaffCapability.manageSku,
          StaffCapability.manageBatches,
          StaffCapability.receiveBatches,

          // Issues
          StaffCapability.approveIssues,
          StaffCapability.disposeStock,
          StaffCapability.requestStock,

          // Reports
          StaffCapability.viewReports,

          // Retail
          StaffCapability.manageSalesDocs,
        };

      case StaffRole.pharmacist:
        return const {
          StaffCapability.requestStock,
          StaffCapability.viewReports,
          // Keep/remove depending on your business rule:
          StaffCapability.manageSalesDocs,
        };

      case StaffRole.prescriber:
        return const {
          StaffCapability.requestStock,
          StaffCapability.viewReports,
        };

      case StaffRole.dispatcher:
        return const {
          StaffCapability.requestStock,
          StaffCapability.viewReports,
        };

      case StaffRole.runner:
        return const {
          StaffCapability.requestStock,
          StaffCapability.viewReports,
        };

      case StaffRole.staff:
        return const {
          StaffCapability.requestStock,
          StaffCapability.viewReports,
        };
    }
  }
}

/// Helpers on role lists.
extension StaffRoleListX on Iterable<StaffRole> {
  StaffRole? get primaryRole {
    if (isEmpty) return null;
    return reduce((a, b) => b.level > a.level ? b : a);
  }

  bool has(StaffCapability cap) => any((r) => r.has(cap));

  bool hasAny(Iterable<StaffCapability> caps) {
    for (final c in caps) {
      if (has(c)) return true;
    }
    return false;
  }

  bool hasAll(Iterable<StaffCapability> caps) {
    for (final c in caps) {
      if (!has(c)) return false;
    }
    return true;
  }

  Set<StaffCapability> get allCapabilities {
    final out = <StaffCapability>{};
    for (final r in this) {
      out.addAll(r.capabilities);
    }
    return out;
  }
}
