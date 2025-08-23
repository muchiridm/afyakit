import 'package:afyakit/features/auth_users/user_manager/extensions/user_role_x.dart';

String labelForUserRole(UserRole role) {
  return switch (role) {
    UserRole.admin => 'Admin',
    UserRole.manager => 'Manager',
    UserRole.staff => 'Staff',
    UserRole.owner => 'Owner',
    UserRole.client => 'Client',
  };
}
