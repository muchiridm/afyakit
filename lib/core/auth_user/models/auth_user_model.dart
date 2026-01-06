// lib/core/auth_users/models/auth_user_model.dart

import 'package:afyakit/core/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth_user/extensions/user_status_x.dart';
import 'package:afyakit/core/auth_user/extensions/user_type_x.dart';

class AuthUser {
  // ────────────── Identity (immutable) ──────────────
  final String uid;
  final String phoneNumber; // canonical Firebase identity (E.164)
  final String tenantId; // membership scope

  // ────────────── Status / type ──────────────
  final UserStatus status; // active | disabled | invited
  final UserType type; // member | staff

  // ────────────── Profile / membership ──────────────
  final String displayName;
  final List<String> stores;
  final String? avatarUrl;

  /// Tenant-scoped email (NOT Firebase Auth email).
  final String? email;

  /// Tenant-scoped human account number (e.g. DP-000123).
  ///
  /// This is the member/staff account number within a tenant and can be kept
  /// in sync with external systems (e.g. Zoho Books contact_number).
  final String? accountNumber;

  /// Normalized Firebase custom claims for this session (optional).
  final Map<String, dynamic>? claims;

  /// HQ / platform-level superadmin (optional; mostly for AfyaKit HQ).
  final bool isSuperAdmin;

  /// Multi-role staff capabilities.
  ///
  /// Empty list ⇒ no specific staff capabilities.
  /// `type` controls the high-level “member vs staff” dashboard behavior.
  final List<StaffRole> staffRoles;

  const AuthUser({
    required this.uid,
    required this.phoneNumber,
    required this.tenantId,
    this.status = UserStatus.active,
    this.type = UserType.member,
    this.displayName = '',
    this.stores = const [],
    this.avatarUrl,
    this.email,
    this.accountNumber,
    this.claims,
    this.isSuperAdmin = false,
    this.staffRoles = const [],
  });

  // ────────────── Parsing ──────────────

  factory AuthUser.fromMap(Map<String, dynamic> json) {
    final uid = (json['uid'] ?? '').toString().trim();
    final phone = (json['phoneNumber'] ?? '').toString().trim();
    final tenant = (json['tenantId'] ?? '').toString().trim();

    if (uid.isEmpty) throw ArgumentError('AuthUser requires uid');
    if (phone.isEmpty) throw ArgumentError('AuthUser requires phoneNumber');
    if (tenant.isEmpty) throw ArgumentError('AuthUser requires tenantId');

    // Optional claims (may be absent for most flows)
    Map<String, dynamic>? parsedClaims;
    final rawClaims = json['claims'];
    if (rawClaims is Map) {
      parsedClaims = rawClaims.map((k, v) => MapEntry(k.toString(), v));
    }

    final isSuperAdmin = json['isSuperAdmin'] == true;

    // Multi-role staffRoles (string[] → StaffRole[])
    final parsedStaffRoles = <StaffRole>[];
    final rawStaffRoles = json['staffRoles'];
    if (rawStaffRoles is List) {
      for (final v in rawStaffRoles) {
        final name = v.toString().trim();
        final parsed = StaffRole.tryParse(name);
        if (parsed != null) parsedStaffRoles.add(parsed);
      }
    }

    // UserType:
    //  - prefer explicit `type` / `userType` from backend
    //  - otherwise derive from staffRoles / isSuperAdmin
    UserType type;
    final rawType = json['type'] ?? json['userType'];
    if (rawType is String) {
      type = UserType.fromString(rawType);
    } else if (parsedStaffRoles.isNotEmpty || isSuperAdmin) {
      type = UserType.staff;
    } else {
      type = UserType.member;
    }

    return AuthUser(
      uid: uid,
      phoneNumber: phone,
      tenantId: tenant,
      status: UserStatus.fromString(json['status'] ?? 'active'),
      type: type,
      displayName: (json['displayName'] ?? '').toString(),
      stores: (json['stores'] is List)
          ? (json['stores'] as List).whereType<String>().toList()
          : const [],
      avatarUrl: (json['avatarUrl'] as String?)?.trim(),
      email: (json['email'] as String?)?.trim(),
      accountNumber: (json['accountNumber'] as String?)?.trim(),
      claims: parsedClaims,
      isSuperAdmin: isSuperAdmin,
      staffRoles: parsedStaffRoles,
    );
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      AuthUser.fromMap(json);

  // ────────────── Mutable bits only ──────────────

  AuthUser copyWith({
    UserStatus? status,
    UserType? type,
    String? displayName,
    List<String>? stores,
    String? avatarUrl,
    String? email,
    String? accountNumber,
    Map<String, dynamic>? claims,
    bool? isSuperAdmin,
    List<StaffRole>? staffRoles,
  }) {
    return AuthUser(
      uid: uid, // immutable
      phoneNumber: phoneNumber, // immutable
      tenantId: tenantId, // immutable
      status: status ?? this.status,
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
      stores: stores ?? this.stores,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      accountNumber: accountNumber ?? this.accountNumber,
      claims: claims ?? this.claims,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      staffRoles: staffRoles ?? this.staffRoles,
    );
  }

  // Full serialization (for caching / logging); not for PATCH.
  Map<String, dynamic> toMap() => {
    'uid': uid,
    'phoneNumber': phoneNumber,
    'tenantId': tenantId,
    'status': status.wire,
    'type': type.wire,
    'displayName': displayName,
    'stores': stores,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    if (email != null && email!.isNotEmpty) 'email': email,
    if (accountNumber != null && accountNumber!.isNotEmpty)
      'accountNumber': accountNumber,
    if (claims != null && claims!.isNotEmpty) 'claims': claims,
    if (isSuperAdmin) 'isSuperAdmin': true,
    if (staffRoles.isNotEmpty)
      'staffRoles': staffRoles.map((r) => r.name).toList(),
  };
}
