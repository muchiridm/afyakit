import 'package:afyakit/shared/utils/normalize/normalize_string.dart';
import 'package:afyakit/users/models/auth_user_status_enum.dart';
import 'package:afyakit/users/models/user_role_enum.dart';
import 'package:afyakit/users/utils/parse_user_role.dart';
import 'package:afyakit/users/models/auth_user.dart';
import 'package:afyakit/users/models/user_profile.dart';

class CombinedUser {
  final String uid;
  final String email;
  final String? phoneNumber;
  final AuthUserStatus status;
  final String tenantId;
  final DateTime? invitedOn;
  final DateTime? activatedOn;

  final String displayName;
  final UserRole role;
  final List<String> stores;
  final String? avatarUrl;

  CombinedUser({
    required this.uid,
    required this.email,
    required this.phoneNumber,
    required this.status,
    required this.tenantId,
    required this.invitedOn,
    required this.activatedOn,
    required this.displayName,
    required this.role,
    required this.stores,
    required this.avatarUrl,
  });

  /// 📦 Combines AuthUser + UserProfile
  factory CombinedUser.from(AuthUser auth, UserProfile profile) {
    return CombinedUser(
      uid: auth.uid,
      email: auth.email,
      phoneNumber: auth.phoneNumber,
      status: AuthUserStatus.fromString(auth.status),
      tenantId: auth.tenantId,
      invitedOn: auth.invitedOn,
      activatedOn: auth.activatedOn,
      displayName: profile.displayName,
      role: _resolveRole(auth.claims?['role'], profile.role),
      stores: profile.stores
          .expand((s) => s.split(','))
          .map((s) => s.normalize())
          .where((s) => s.isNotEmpty)
          .toList(),
      avatarUrl: profile.avatarUrl,
    );
  }

  /// 🧩 Fallback: auth-only user with no profile
  factory CombinedUser.fromAuthOnly(AuthUser auth) {
    return CombinedUser(
      uid: auth.uid,
      email: auth.email,
      phoneNumber: auth.phoneNumber,
      status: AuthUserStatus.fromString(auth.status),
      tenantId: auth.tenantId,
      invitedOn: auth.invitedOn,
      activatedOn: auth.activatedOn,
      displayName: '',
      role: _resolveRole(auth.claims?['role'], UserRole.staff),
      stores: [],
      avatarUrl: null,
    );
  }

  /// 🆕 Placeholder user
  factory CombinedUser.blank() => CombinedUser(
    uid: '',
    email: '',
    phoneNumber: null,
    status: AuthUserStatus.invited,
    tenantId: '',
    invitedOn: null,
    activatedOn: null,
    displayName: '',
    role: UserRole.staff,
    stores: [],
    avatarUrl: null,
  );

  // ────────────────────────────────────────────────
  // 🔁 Copy helper
  // ────────────────────────────────────────────────
  CombinedUser copyWith({
    String? uid,
    String? email,
    String? phoneNumber,
    AuthUserStatus? status,
    String? tenantId,
    DateTime? invitedOn,
    DateTime? activatedOn,
    String? displayName,
    UserRole? role,
    List<String>? stores,
    String? avatarUrl,
  }) {
    return CombinedUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      status: status ?? this.status,
      tenantId: tenantId ?? this.tenantId,
      invitedOn: invitedOn ?? this.invitedOn,
      activatedOn: activatedOn ?? this.activatedOn,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      stores: stores ?? this.stores,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  // ────────────────────────────────────────────────
  // 🔐 Role resolution (claims > profile fallback)
  // ────────────────────────────────────────────────
  static UserRole _resolveRole(String? claimRole, UserRole fallback) {
    return parseUserRole(claimRole ?? fallback.name);
  }
}
