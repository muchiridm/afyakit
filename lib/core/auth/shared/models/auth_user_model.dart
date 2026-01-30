// lib/core/auth_user/models/auth_user_model.dart

import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth/auth_user/extensions/user_status_x.dart';
import 'package:afyakit/core/auth/auth_user/extensions/user_type_x.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_zoho_link.dart';

/// Backend-aligned Zoho mapping for this auth user (tenant-scoped).

class AuthUser {
  // ────────────── Identity (immutable) ──────────────
  final String uid;
  final String phoneNumber; // canonical Firebase identity (E.164)
  final String tenantId; // membership scope

  // ────────────── Status / type ──────────────
  final UserStatus status; // active | disabled (BE); keep tolerant
  final UserType type; // member | staff

  // ────────────── Membership / access ──────────────
  final List<String> stores;

  // ────────────── Profile ──────────────
  final String? firstName;
  final String? lastName;

  /// Backend may send displayName or omit it; keep nullable but provide a computed fallback.
  final String? displayName;

  final String? avatarUrl;

  /// Tenant-scoped email (NOT Firebase Auth email). Backend only exposes it when verified.
  final String? email;
  final String? emailLower;

  final bool phoneVerified;
  final String? phoneVerifiedAt; // ISO string

  final bool emailVerified;
  final String? emailVerifiedAt; // ISO string

  final bool isCompany;
  final String? companyName;

  /// Tenant-scoped human account number (e.g. DP-000123).
  final String? accountNumber;

  /// Backend-owned mapping to Zoho Books contact/person (tenant-scoped).
  final AuthUserZohoLink? zoho;

  /// Normalized Firebase custom claims for this session (optional).
  final Map<String, dynamic>? claims;

  /// HQ / platform-level superadmin (optional).
  final bool isSuperAdmin;

  /// Multi-role staff capabilities.
  final List<StaffRole> staffRoles;

  final String? createdAt; // ISO string
  final String? updatedAt; // ISO string

  const AuthUser({
    required this.uid,
    required this.phoneNumber,
    required this.tenantId,
    required this.status,
    required this.type,
    this.stores = const [],
    this.firstName,
    this.lastName,
    this.displayName,
    this.avatarUrl,
    this.email,
    this.emailLower,
    this.phoneVerified = false,
    this.phoneVerifiedAt,
    this.emailVerified = false,
    this.emailVerifiedAt,
    this.isCompany = false,
    this.companyName,
    this.accountNumber,
    this.zoho,
    this.claims,
    this.isSuperAdmin = false,
    this.staffRoles = const [],
    this.createdAt,
    this.updatedAt,
  });

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  static String _cleanStr(dynamic v) => (v ?? '').toString().trim();

  static String? _optStr(dynamic v) {
    final s = _cleanStr(v);
    return s.isEmpty ? null : s;
  }

  static bool _bool(dynamic v) => v == true;

  static List<String> _normalizeStores(dynamic raw) {
    final out = <String>[];

    if (raw is List) {
      for (final v in raw) {
        final s = _cleanStr(v);
        if (s.isNotEmpty) out.add(s);
      }
    } else if (raw is String) {
      for (final p in raw.split(',')) {
        final s = p.trim();
        if (s.isNotEmpty) out.add(s);
      }
    }

    final seen = <String>{};
    return out.where(seen.add).toList();
  }

  static Map<String, dynamic>? _normalizeClaims(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static List<StaffRole> _normalizeStaffRoles(dynamic raw) {
    if (raw is! List) return const [];
    final out = <StaffRole>[];
    for (final v in raw) {
      final name = _cleanStr(v);
      final parsed = StaffRole.tryParse(name);
      if (parsed != null) out.add(parsed);
    }
    final seen = <String>{};
    return out.where((r) => seen.add(r.name)).toList();
  }

  static UserStatus _parseStatus(dynamic raw) {
    final s = _cleanStr(raw).toLowerCase();
    // Backend: active|disabled. Keep tolerant if FE enum adds more later.
    try {
      return UserStatus.fromString(s.isEmpty ? 'active' : s);
    } catch (_) {
      return UserStatus.active;
    }
  }

  static UserType _parseType({
    required dynamic rawType,
    required List<StaffRole> staffRoles,
    required bool isSuperAdmin,
  }) {
    final s = rawType is String ? rawType.trim() : '';
    if (s.isNotEmpty) {
      try {
        return UserType.fromString(s);
      } catch (_) {
        // fall through
      }
    }
    if (staffRoles.isNotEmpty || isSuperAdmin) return UserType.staff;
    return UserType.member;
  }

  String get computedDisplayName {
    final dn = (displayName ?? '').trim();
    if (dn.isNotEmpty) return dn;

    final f = (firstName ?? '').trim();
    final l = (lastName ?? '').trim();
    final name = ('$f $l').trim();
    if (name.isNotEmpty) return name;

    if (isCompany) {
      final cn = (companyName ?? '').trim();
      if (cn.isNotEmpty) return cn;
    }

    return phoneNumber;
  }

  // ────────────── Parsing ──────────────

  factory AuthUser.fromMap(Map<String, dynamic> json) {
    final uid = _cleanStr(json['uid']);
    final phone = _cleanStr(json['phoneNumber']);
    final tenant = _cleanStr(json['tenantId']);

    if (uid.isEmpty) throw ArgumentError('AuthUser requires uid');
    if (phone.isEmpty) throw ArgumentError('AuthUser requires phoneNumber');
    if (tenant.isEmpty) throw ArgumentError('AuthUser requires tenantId');

    final claims = _normalizeClaims(json['claims']);
    final isSuperAdmin = _bool(json['isSuperAdmin']);
    final staffRoles = _normalizeStaffRoles(json['staffRoles']);

    final type = _parseType(
      rawType: json['type'] ?? json['userType'],
      staffRoles: staffRoles,
      isSuperAdmin: isSuperAdmin,
    );

    AuthUserZohoLink? zoho;
    final rawZoho = json['zoho'];
    if (rawZoho is Map) {
      try {
        zoho = AuthUserZohoLink.fromMap(
          Map<String, dynamic>.from(
            rawZoho.map((k, v) => MapEntry(k.toString(), v)),
          ),
        );
      } catch (_) {
        zoho = null;
      }
    }

    final phoneVerified = _bool(json['phoneVerified']);
    final emailVerified = _bool(json['emailVerified']);
    final isCompany = _bool(json['isCompany']);

    // Backend already hides unverified emails; still keep safe.
    final email = _optStr(json['email'])?.toLowerCase();
    final emailLower = _optStr(json['emailLower'])?.toLowerCase();

    final safeEmail = emailVerified ? email : null;
    final safeEmailLower = emailVerified ? (emailLower ?? email) : null;

    return AuthUser(
      uid: uid,
      phoneNumber: phone,
      tenantId: tenant,
      status: _parseStatus(json['status']),
      type: type,
      stores: _normalizeStores(json['stores']),
      firstName: _optStr(json['firstName']),
      lastName: _optStr(json['lastName']),
      displayName: _optStr(json['displayName']),
      avatarUrl: _optStr(json['avatarUrl']),
      email: safeEmail,
      emailLower: safeEmailLower,

      phoneVerified: phoneVerified,
      phoneVerifiedAt: _optStr(json['phoneVerifiedAt']),
      emailVerified: emailVerified,
      emailVerifiedAt: _optStr(json['emailVerifiedAt']),
      isCompany: isCompany,
      companyName: _optStr(json['companyName']),
      accountNumber: _optStr(json['accountNumber']),
      zoho: zoho,
      claims: claims,
      isSuperAdmin: isSuperAdmin,
      staffRoles: staffRoles,
      createdAt: _optStr(json['createdAt']),
      updatedAt: _optStr(json['updatedAt']),
    );
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      AuthUser.fromMap(json);

  AuthUser copyWith({
    UserStatus? status,
    UserType? type,
    List<String>? stores,
    String? firstName,
    String? lastName,
    String? displayName,
    String? avatarUrl,
    String? email,
    String? emailLower,
    bool? phoneVerified,
    String? phoneVerifiedAt,
    bool? emailVerified,
    String? emailVerifiedAt,
    bool? isCompany,
    String? companyName,
    String? accountNumber,
    AuthUserZohoLink? zoho,
    Map<String, dynamic>? claims,
    bool? isSuperAdmin,
    List<StaffRole>? staffRoles,
    String? createdAt,
    String? updatedAt,
  }) {
    return AuthUser(
      uid: uid,
      phoneNumber: phoneNumber,
      tenantId: tenantId,
      status: status ?? this.status,
      type: type ?? this.type,
      stores: stores ?? this.stores,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      emailLower: emailLower ?? this.emailLower,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      phoneVerifiedAt: phoneVerifiedAt ?? this.phoneVerifiedAt,
      emailVerified: emailVerified ?? this.emailVerified,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      isCompany: isCompany ?? this.isCompany,
      companyName: companyName ?? this.companyName,
      accountNumber: accountNumber ?? this.accountNumber,
      zoho: zoho ?? this.zoho,
      claims: claims ?? this.claims,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      staffRoles: staffRoles ?? this.staffRoles,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'phoneNumber': phoneNumber,
    'tenantId': tenantId,
    'status': status.wire,
    'type': type.wire,
    'stores': stores,
    if (firstName != null) 'firstName': firstName,
    if (lastName != null) 'lastName': lastName,
    if (displayName != null) 'displayName': displayName,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    if (email != null) 'email': email,
    if (emailLower != null) 'emailLower': emailLower,
    if (phoneVerified) 'phoneVerified': true,
    if (phoneVerifiedAt != null) 'phoneVerifiedAt': phoneVerifiedAt,
    if (emailVerified) 'emailVerified': true,
    if (emailVerifiedAt != null) 'emailVerifiedAt': emailVerifiedAt,
    if (isCompany) 'isCompany': true,
    if (companyName != null) 'companyName': companyName,
    if (accountNumber != null) 'accountNumber': accountNumber,
    if (zoho != null) 'zoho': zoho!.toMap(),
    if (claims != null && claims!.isNotEmpty) 'claims': claims,
    if (isSuperAdmin) 'isSuperAdmin': true,
    if (staffRoles.isNotEmpty)
      'staffRoles': staffRoles.map((r) => r.name).toList(),
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };
}
