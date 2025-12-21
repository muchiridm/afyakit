// lib/core/auth_users/extensions/user_type_x.dart

/// High-level user type within a tenant.
///
/// - `member`: baseline for *everyone* (clients / patients / members).
/// - `staff`: users who have staff capabilities; they are also members.
///
/// Identity (uid, phoneNumber, tenantId) is orthogonal; this just says
/// how the app should treat them in terms of dashboards / flows.
enum UserType {
  member,
  staff;

  /// Strict parser with least-privilege fallback.
  static UserType fromString(String input) {
    final s = input.trim().toLowerCase();
    for (final t in UserType.values) {
      if (t.name == s) return t;
    }
    // Default to member (least privilege).
    return UserType.member;
  }

  /// Nullable parser; returns null when unknown.
  static UserType? tryParse(String? input) {
    if (input == null) return null;
    final s = input.trim().toLowerCase();
    for (final t in UserType.values) {
      if (t.name == s) return t;
    }
    return null;
  }

  /// Stable, backend-facing name.
  String get wire => toString().split('.').last;

  /// Back-compat convenience (same as [wire]), if you ever need it.
  String get name => wire;
}

extension UserTypeX on UserType {
  /// In your model, *everyone* is a member.
  bool get isMember => true;

  /// Only staff users are considered staff.
  bool get isStaff => this == UserType.staff;

  /// Handy for UI labels.
  String get label => switch (this) {
    UserType.member => 'Member',
    UserType.staff => 'Staff',
  };

  /// Simple precedence if you ever need to sort/filter by type.
  int get level => switch (this) {
    UserType.member => 0,
    UserType.staff => 1,
  };

  int compare(UserType other) => level.compareTo(other.level);

  /// Convenience for your two-dashboards world:
  /// - Member dashboard → always visible.
  /// - Staff dashboard → only when this is true.
  bool get hasStaffWorkspace => isStaff;
}
