import '../../user_manager/extensions/user_role_enum.dart';

UserRole parseUserRole(String input) => switch (input.trim().toLowerCase()) {
  'admin' => UserRole.admin,
  'manager' => UserRole.manager,
  _ => UserRole.staff,
};
