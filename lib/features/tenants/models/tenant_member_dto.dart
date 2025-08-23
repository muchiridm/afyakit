import 'package:afyakit/features/auth_users/models/global_user_model.dart';

/// Lightweight view model representing a tenant-scoped membership
/// joined with the global user profile.
/// Used by the Tenant Admins UI.
class TenantMemberDTO {
  /// Global profile (top-level `/users/{uid}`)
  final GlobalUser user;

  /// Membership role within the tenant:
  /// 'owner' | 'admin' | 'manager' | 'staff' | 'client'
  final String role;

  /// Whether the membership is active for this tenant.
  final bool active;

  /// Optional: the tenant this membership belongs to (slug/doc id).
  final String? tenantId;

  /// Optional: server-updated timestamp of the membership record.
  final DateTime? updatedAt;

  const TenantMemberDTO({
    required this.user,
    required this.role,
    required this.active,
    this.tenantId,
    this.updatedAt,
  });

  /// Convenience getters
  String get uid => user.id;
  String get email => user.email ?? user.emailLower;
  bool get isAdmin => role == 'owner' || role == 'admin' || role == 'manager';

  TenantMemberDTO copyWith({
    GlobalUser? user,
    String? role,
    bool? active,
    String? tenantId,
    DateTime? updatedAt,
  }) {
    return TenantMemberDTO(
      user: user ?? this.user,
      role: role ?? this.role,
      active: active ?? this.active,
      tenantId: tenantId ?? this.tenantId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Build from raw membership map (Firestore doc data) plus a GlobalUser.
  /// Keeps this DTO pure (no direct Firestore imports).
  factory TenantMemberDTO.fromMembershipMap({
    required Map<String, dynamic> membership,
    required GlobalUser user,
    String? tenantId,
    DateTime? updatedAt,
  }) {
    return TenantMemberDTO(
      user: user,
      role: (membership['role'] ?? 'staff').toString(),
      active: membership['active'] == true,
      tenantId: tenantId ?? (membership['tenantId'] as String?),
      updatedAt:
          updatedAt ??
          (membership['updatedAt'] is DateTime
              ? membership['updatedAt'] as DateTime
              : null),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'tenantId': tenantId,
    'role': role,
    'active': active,
    'updatedAt': updatedAt?.toIso8601String(),
    'user': {
      'id': user.id,
      'email': user.email,
      'emailLower': user.emailLower,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'disabled': user.disabled,
      'tenantCount': user.tenantCount,
      'lastLoginAt': user.lastLoginAt?.toIso8601String(),
    },
  };
}
