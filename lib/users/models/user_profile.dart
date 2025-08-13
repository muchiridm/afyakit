import 'package:afyakit/users/models/user_role_enum.dart';
import 'package:afyakit/users/utils/parse_user_role.dart';

class UserProfile {
  /// Document ID (not stored inside document)
  final String uid;

  /// Display name (optional, defaults to '')
  final String displayName;

  /// Role is mandatory
  final UserRole role;

  /// List of human-readable store names (defaults to empty list)
  final List<String> stores;

  /// Optional avatar URL
  final String? avatarUrl;

  UserProfile({
    required this.uid,
    required this.role,
    this.displayName = '',
    List<String>? stores,
    this.avatarUrl,
  }) : stores = stores ?? const [];

  /// Creates a UserProfile from Firestore doc data
  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      displayName: map['displayName'] ?? '',
      role: parseUserRole(map['role'] ?? 'staff'),
      stores: List<String>.from(map['stores'] ?? const []),
      avatarUrl: map['avatarUrl'],
    );
  }

  /// Converts profile to a Firestore-friendly map (excludes uid)
  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'role': role.name,
      'stores': stores,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    };
  }

  /// Returns a blank/staff-level user profile with only UID and default role
  factory UserProfile.blank(String uid) {
    return UserProfile(uid: uid, role: UserRole.staff);
  }

  /// Clones the profile with optional overrides
  UserProfile copyWith({
    String? displayName,
    UserRole? role,
    List<String>? stores,
    String? avatarUrl,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      stores: stores ?? this.stores,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
