// lib/users/extensions/user_role_enum.dart
enum UserRole {
  admin,
  manager,
  staff;

  static UserRole fromString(String input) {
    switch (input.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'staff':
      default:
        return UserRole.staff;
    }
  }

  String get name => toString().split('.').last;
}
