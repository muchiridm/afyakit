/// Roles are assigned within one tenant and one app.
enum StaffRole {
  owner, admin, manager, staff, runner, dispatcher, pharmacist, prescriber;

  /// Unknown roles must never become a staff grant.
  static StaffRole fromString(String? input) {
    final role = tryParse(input);
    if (role == null) throw FormatException('Unknown staff role', input);
    return role;
  }
  static StaffRole? tryParse(String? input) {
    final value = (input ?? '').trim().toLowerCase();
    for (final role in values) {
      if (role.name == value) return role;
    }
    return null;
  }
  String get wire => name;
  String get label => switch (this) {
    owner => 'Owner', admin => 'Admin', manager => 'Manager', staff => 'Staff',
    runner => 'Runner', dispatcher => 'Dispatcher', pharmacist => 'Pharmacist',
    prescriber => 'Doctor',
  };
  int get level => switch (this) {
    owner => 7, admin => 6, manager => 5,
    prescriber || pharmacist => 4, dispatcher || runner => 3, staff => 1,
  };
  int compareTo(StaffRole other) => level.compareTo(other.level);

  /// Platform provisioning of owners is separate from these app roles.
  bool canAssignRole(StaffRole target) => switch (this) {
    owner => target != owner,
    admin => target != owner && target != admin,
    _ => false,
  };
  List<StaffRole> assignableTargets() => values.where(canAssignRole).toList(growable: false);
  bool has(StaffCapability cap) => capabilities.contains(cap);
  Set<StaffCapability> get capabilities => StaffRoleCapabilities.of(this);
}

enum StaffCapability {
  accessAdminPanel, manageUsers, manageAllStores,
  manageTenantSettings, manageBilling, transferOwnership, exportAllData, deleteTenant,
  manageSku, manageBatches, receiveBatches,
  approveIssues, disposeStock, requestStock, viewReports, manageSalesDocs,
}

abstract final class StaffRoleCapabilities {
  static const _operations = <StaffCapability>{
    StaffCapability.manageSku, StaffCapability.manageBatches,
    StaffCapability.receiveBatches, StaffCapability.approveIssues,
    StaffCapability.disposeStock, StaffCapability.requestStock,
    StaffCapability.viewReports, StaffCapability.manageSalesDocs,
  };
  static Set<StaffCapability> of(StaffRole role) => switch (role) {
    StaffRole.owner || StaffRole.admin => {
      ..._operations, StaffCapability.accessAdminPanel,
      StaffCapability.manageUsers, StaffCapability.manageAllStores,
    },
    StaffRole.manager => {..._operations, StaffCapability.accessAdminPanel},
    StaffRole.pharmacist => const {
      StaffCapability.requestStock, StaffCapability.viewReports,
      StaffCapability.manageSalesDocs,
    },
    _ => const {StaffCapability.requestStock, StaffCapability.viewReports},
  };
}

extension StaffRoleListX on Iterable<StaffRole> {
  StaffRole? get primaryRole => isEmpty ? null : reduce((a, b) => b.level > a.level ? b : a);
  bool has(StaffCapability cap) => any((role) => role.has(cap));
  bool hasAny(Iterable<StaffCapability> caps) => caps.any(has);
  bool hasAll(Iterable<StaffCapability> caps) => caps.every(has);
  Set<StaffCapability> get allCapabilities => {
    for (final role in this) ...role.capabilities,
  };
}
