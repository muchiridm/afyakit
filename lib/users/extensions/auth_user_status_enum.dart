enum AuthUserStatus {
  active,
  invited,
  disabled;

  static AuthUserStatus fromString(String input) {
    switch (input.toLowerCase()) {
      case 'active':
        return AuthUserStatus.active;
      case 'invited':
        return AuthUserStatus.invited;
      case 'disabled':
        return AuthUserStatus.disabled;
      default:
        return AuthUserStatus.invited; // fallback for legacy/missing data
    }
  }

  String get name => toString().split('.').last;
}
