import 'package:afyakit/users/user_manager/extensions/user_role_enum.dart';

extension UserRoleX on UserRole {
  bool get isAdmin => this == UserRole.admin;
  bool get isManager => this == UserRole.manager;
  bool get isStaff => this == UserRole.staff;

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

  bool get isViewOnly => isStaff;

  String get label => switch (this) {
    UserRole.admin => 'Admin',
    UserRole.manager => 'Manager',
    UserRole.staff => 'Staff',
  };

  int get level => switch (this) {
    UserRole.admin => 3,
    UserRole.manager => 2,
    UserRole.staff => 1,
  };

  bool canAssignRole(UserRole target) {
    if (isAdmin) return true;
    if (isManager) return target != UserRole.admin;
    return false;
  }
}

// Back-compat helper if other code calls parseUserRole(...)
UserRole parseUserRole(String input) => UserRole.fromString(input);
