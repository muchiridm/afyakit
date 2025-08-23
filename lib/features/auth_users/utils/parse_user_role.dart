import 'package:afyakit/features/auth_users/user_manager/extensions/user_role_x.dart';

UserRole parseUserRole(String input) => switch (input.trim().toLowerCase()) {
  'admin' => UserRole.admin,
  'manager' => UserRole.manager,
  _ => UserRole.staff,
};
