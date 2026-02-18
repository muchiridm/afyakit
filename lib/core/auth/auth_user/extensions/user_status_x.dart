// lib/core/auth_users/extensions/user_status_x.dart

/// Tenant-scoped user status.
///
/// New auth flow deliberately keeps this simple:
/// - active   → user may access the app
/// - disabled → user is blocked (must sign out / contact admin)
///
/// Any unknown / legacy values are treated as [active]
/// to avoid accidentally locking users out.
enum UserStatus {
  active,
  disabled;

  // ─────────────────────────────────────────────
  // Parsing
  // ─────────────────────────────────────────────

  /// Safe parse from API / Firestore / legacy strings.
  ///
  /// Unknown values default to [UserStatus.active].
  static UserStatus fromString(String? input) {
    switch ((input ?? '').trim().toLowerCase()) {
      case 'disabled':
        return UserStatus.disabled;
      case 'active':
      default:
        return UserStatus.active;
    }
  }

  /// Same as [fromString] but returns null when input is empty.
  /// Useful when status is optional in a payload.
  static UserStatus? maybeFrom(String? input) {
    final v = (input ?? '').trim();
    if (v.isEmpty) return null;
    return fromString(v);
  }

  // ─────────────────────────────────────────────
  // Wire / UI helpers
  // ─────────────────────────────────────────────

  /// Lowercase value sent over the wire / stored in Firestore.
  String get wire => name; // "active" | "disabled"

  /// Human-friendly label.
  String get label => this == UserStatus.active ? 'Active' : 'Disabled';

  // ─────────────────────────────────────────────
  // Semantics
  // ─────────────────────────────────────────────

  /// True when the user should NOT be allowed into the app.
  bool get isBlocked => this == UserStatus.disabled;

  bool get isActive => this == UserStatus.active;
  bool get isDisabled => this == UserStatus.disabled;
}
