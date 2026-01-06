// lib/core/auth_users/extensions/user_status_x.dart

enum UserStatus {
  active,
  disabled;

  static UserStatus fromString(String input) {
    switch (input.trim().toLowerCase()) {
      case 'active':
        return UserStatus.active;
      case 'disabled':
        return UserStatus.disabled;
      default:
        return UserStatus.active;
    }
  }

  String get wire => toString().split('.').last;
}

extension UserStatusX on UserStatus {
  bool get isActive => this == UserStatus.active;
  bool get isDisabled => this == UserStatus.disabled;

  String get label => switch (this) {
    UserStatus.active => 'Active',
    UserStatus.disabled => 'Disabled',
  };
}
