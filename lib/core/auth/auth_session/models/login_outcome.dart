// lib/core/auth_users/models/login_outcome.dart
enum LoginMode { active, limited } // limited == invited/inactive

class LoginOutcome {
  final LoginMode mode; // active or limited
  final bool claimsSynced; // only meaningful when mode == active

  const LoginOutcome({required this.mode, this.claimsSynced = false});

  bool get isLimited => mode == LoginMode.limited;
  bool get isActive => mode == LoginMode.active;
}
