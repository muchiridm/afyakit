import 'package:afyakit/users/extensions/user_role_enum.dart';

String labelForUserRole(UserRole role) {
  return switch (role) {
    UserRole.admin => 'Admin',
    UserRole.manager => 'Manager',
    UserRole.staff => 'Staff',
  };
}
