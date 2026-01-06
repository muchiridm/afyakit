// lib/hq/tenants/dtos/team_member_dto.dart

import 'package:afyakit/features/hq/users/all_users/all_user_model.dart';

/// Lightweight view model representing a tenant-scoped membership
/// joined with the global user profile (for the Admins screen).
class TenantMemberDTO {
  final AllUser user;

  /// 'owner' | 'admin' | 'manager' | 'staff' | 'client'
  final String role;

  /// Whether membership is active (server: status === 'active')
  final bool active;

  /// Tenant slug this membership belongs to (optional when deduced upstream)
  final String? tenantId;

  /// Server-updated timestamp of the membership record (optional)
  final DateTime? updatedAt;

  const TenantMemberDTO({
    required this.user,
    required this.role,
    required this.active,
    this.tenantId,
    this.updatedAt,
  });

  String get uid => user.id;
  String get email => user.email ?? user.emailLower;
  bool get isAdmin => role == 'owner' || role == 'admin' || role == 'manager';

  TenantMemberDTO copyWith({
    AllUser? user,
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

  /// Build from a membership map (e.g. from /users/{uid}/memberships/{tenantId})
  factory TenantMemberDTO.fromMembershipMap({
    required Map<String, dynamic> membership,
    required AllUser user,
    String? tenantId,
    DateTime? updatedAt,
  }) {
    final role = (membership['role'] ?? 'staff').toString();
    final status =
        (membership['status'] ?? (membership['active'] == true ? 'active' : ''))
            .toString()
            .toLowerCase();
    final isActive = membership['active'] == true || status == 'active';

    return TenantMemberDTO(
      user: user,
      role: role,
      active: isActive,
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
