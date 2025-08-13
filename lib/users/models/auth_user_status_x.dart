// File: lib/users/src/utils/auth_user_status_x.dart

import 'package:afyakit/users/models/auth_user_status_enum.dart';

extension AuthUserStatusX on AuthUserStatus {
  bool get isActive => this == AuthUserStatus.active;
  bool get isInvited => this == AuthUserStatus.invited;
  bool get isDisabled => this == AuthUserStatus.disabled;

  bool get isPending => this == AuthUserStatus.invited;

  String get label {
    switch (this) {
      case AuthUserStatus.active:
        return 'Active';
      case AuthUserStatus.invited:
        return 'Invited';
      case AuthUserStatus.disabled:
        return 'Disabled';
    }
  }
}
