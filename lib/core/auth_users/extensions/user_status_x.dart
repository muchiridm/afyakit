// lib/users/user_manager/extensions/user_status_x.dart

enum UserStatus {
  active,
  invited,
  disabled;

  static UserStatus fromString(String input) {
    switch (input.trim().toLowerCase()) {
      case 'active':
        return UserStatus.active;
      case 'invited':
        return UserStatus.invited;
      case 'disabled':
        return UserStatus.disabled;
      default:
        // fallback for legacy/missing data
        return UserStatus.invited;
    }
  }

  /// Stable, backend-facing name.
  String get wire => toString().split('.').last;

  /// Back-compat with older call sites.
  String get name => wire;
}

extension UserStatusX on UserStatus {
  bool get isActive => this == UserStatus.active;
  bool get isInvited => this == UserStatus.invited;
  bool get isDisabled => this == UserStatus.disabled;

  bool get isPending => this == UserStatus.invited;

  String get label => switch (this) {
    UserStatus.active => 'Active',
    UserStatus.invited => 'Invited',
    UserStatus.disabled => 'Disabled',
  };
}
