import 'package:afyakit/core/auth_user/extensions/staff_role_x.dart';

StaffRole parseUserRole(String input) => switch (input.trim().toLowerCase()) {
  'admin' => StaffRole.admin,
  'manager' => StaffRole.manager,
  _ => StaffRole.staff,
};
