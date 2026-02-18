// lib/core/auth_users/extensions/user_type_x.dart

/// High-level user type within a tenant.
///
/// - member: baseline users (clients/patients/members)
/// - staff: users with staff capabilities
enum UserType {
  member,
  staff;

  // ─────────────────────────────────────────────
  // Parsing
  // ─────────────────────────────────────────────

  /// Safe parse with least-privilege fallback.
  /// Unknown → [UserType.member].
  static UserType fromString(String? input) {
    final s = (input ?? '').trim().toLowerCase();
    for (final t in UserType.values) {
      if (t.name == s) return t;
    }
    return UserType.member;
  }

  /// Nullable parse; returns null when unknown/empty.
  static UserType? tryParse(String? input) {
    final s = (input ?? '').trim().toLowerCase();
    if (s.isEmpty) return null;
    for (final t in UserType.values) {
      if (t.name == s) return t;
    }
    return null;
  }

  // ─────────────────────────────────────────────
  // Wire / UI helpers
  // ─────────────────────────────────────────────

  /// Backend-facing string value (lowercase).
  String get wire => name;

  String get label => this == UserType.member ? 'Member' : 'Staff';

  // ─────────────────────────────────────────────
  // Semantics
  // ─────────────────────────────────────────────

  bool get isMember => this == UserType.member;
  bool get isStaff => this == UserType.staff;

  /// Ordering if you ever need to sort types.
  int get level => this == UserType.staff ? 1 : 0;

  int compareTo(UserType other) => level.compareTo(other.level);

  /// Everyone can use the member-facing experience;
  /// staff additionally have a staff workspace.
  bool get hasStaffWorkspace => isStaff;
}
