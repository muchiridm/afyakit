import 'package:afyakit/core/auth_users/extensions/user_role_x.dart';

UserRole parseUserRole(String input) => switch (input.trim().toLowerCase()) {
  'admin' => UserRole.admin,
  'manager' => UserRole.manager,
  _ => UserRole.staff,
};
