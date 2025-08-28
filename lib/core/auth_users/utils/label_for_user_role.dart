import 'package:afyakit/core/auth_users/extensions/user_role_x.dart';

String labelForUserRole(UserRole role) {
  return switch (role) {
    UserRole.admin => 'Admin',
    UserRole.manager => 'Manager',
    UserRole.staff => 'Staff',
    UserRole.owner => 'Owner',
    UserRole.client => 'Client',
  };
}
