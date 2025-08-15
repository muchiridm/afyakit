// lib/users/models/auth_user_model.dart
import 'package:flutter/foundation.dart';
import 'package:afyakit/shared/utils/normalize/normalize_date.dart';
import 'package:afyakit/shared/utils/normalize/normalize_string.dart';
import 'package:afyakit/users/extensions/user_role_enum.dart';
import 'package:afyakit/users/utils/parse_user_role.dart';

class AuthUser {
  // ── auth / session fields
  final String uid;
  final String email;
  final String? phoneNumber;
  final String status; // 'invited' | 'active' | 'disabled'
  final String tenantId;
  final DateTime? invitedOn;
  final DateTime? activatedOn;
  final Map<String, dynamic>? claims;

  // ── profile fields (moved here)
  final String displayName; // '' by default
  final UserRole role; // claims win at runtime; stored as fallback
  final List<String> stores; // normalized, deduped
  final String? avatarUrl;

  const AuthUser({
    required this.uid,
    required this.email,
    required this.status,
    required this.tenantId,
    this.phoneNumber,
    this.invitedOn,
    this.activatedOn,
    this.claims,
    this.displayName = '',
    this.role = UserRole.staff,
    this.stores = const [],
    this.avatarUrl,
  });

  bool get isSuperAdmin => claims?['superadmin'] == true;

  AuthUser copyWith({
    String? uid,
    String? email,
    String? phoneNumber,
    String? status,
    String? tenantId,
    DateTime? invitedOn,
    DateTime? activatedOn,
    Map<String, dynamic>? claims,
    String? displayName,
    UserRole? role,
    List<String>? stores,
    String? avatarUrl,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      status: status ?? this.status,
      tenantId: tenantId ?? this.tenantId,
      invitedOn: invitedOn ?? this.invitedOn,
      activatedOn: activatedOn ?? this.activatedOn,
      claims: claims ?? this.claims,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      stores: stores ?? this.stores,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  // ✅ Updated: prefer top-level fields, fallback to `claims`
  factory AuthUser.fromMap(String uid, Map<String, dynamic> json) {
    // Pull claims early (and make it a proper map)
    final Map<String, dynamic>? claims = (json['claims'] is Map)
        ? Map<String, dynamic>.from(json['claims'])
        : null;

    String _s(dynamic v) => (v ?? '').toString().trim();

    // email / phone
    final email = _s(json['email']);
    final phone = _s(json['phoneNumber']).isNotEmpty
        ? _s(json['phoneNumber'])
        : (_s(claims?['phone']).isNotEmpty
              ? _s(claims?['phone'])
              : _s(claims?['phone_number']));

    // tenantId (top-level → claims)
    final tenantId = _s(json['tenantId']).isNotEmpty
        ? _s(json['tenantId'])
        : (_s(claims?['tenant']).isNotEmpty
              ? _s(claims?['tenant'])
              : (_s(claims?['tenantId']).isNotEmpty
                    ? _s(claims?['tenantId'])
                    : _s(claims?['tenant_id'])));

    // status
    final status = _s(json['status']).isNotEmpty
        ? _s(json['status'])
        : 'invited';

    // role (top-level → claims → staff)
    final rawRole = _s(json['role']);
    final claimRole = _s(claims?['role']);
    final roleStr = rawRole.isNotEmpty ? rawRole : claimRole;
    final role = parseUserRole(roleStr.isNotEmpty ? roleStr : 'staff');

    // displayName (top-level → claims.displayName/name)
    final displayName = _s(json['displayName']).isNotEmpty
        ? _s(json['displayName'])
        : (_s(claims?['displayName']).isNotEmpty
              ? _s(claims?['displayName'])
              : _s(claims?['name']));

    // stores (top-level → claims.stores)
    List<String> storesModel = _normalizeStores(json['stores']);
    final List<String> storesClaims = _normalizeStores(claims?['stores']);
    if (storesModel.isEmpty && storesClaims.isNotEmpty) {
      storesModel = storesClaims;
    }

    final obj = AuthUser(
      uid: uid,
      email: email,
      phoneNumber: phone.isNotEmpty ? phone : null,
      status: status,
      tenantId: tenantId,
      invitedOn: normalizeDate(json['invitedOn']),
      activatedOn: normalizeDate(json['activatedOn']),
      claims: claims,
      displayName: displayName,
      role: role,
      stores: storesModel,
      avatarUrl: (_s(json['avatarUrl']).isNotEmpty)
          ? _s(json['avatarUrl'])
          : null,
    );

    if (kDebugMode) {
      debugPrint(
        '🧩 [AuthUser.fromMap] uid=${obj.uid} email=${obj.email} '
        'status=${obj.status} role=${obj.role.name} stores=${obj.stores}',
      );
    }

    // invariants
    final hasEmail = obj.email.trim().isNotEmpty;
    final hasPhone = obj.phoneNumber?.trim().isNotEmpty == true;
    if (!hasEmail && !hasPhone) {
      throw ArgumentError(
        '❌ AuthUser must have at least an email or phone number',
      );
    }
    if (obj.tenantId.trim().isEmpty) {
      throw ArgumentError('❌ AuthUser must have a valid tenantId');
    }
    return obj;
  }

  // JSON variant (rarely used client-side)
  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      AuthUser.fromMap((json['uid'] ?? '').toString(), json);

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phoneNumber': phoneNumber,
      'status': status,
      'tenantId': tenantId,
      'invitedOn': invitedOn?.toIso8601String(),
      'activatedOn': activatedOn?.toIso8601String(),
      if (claims != null) 'claims': claims,
      'displayName': displayName,
      'role': role.name,
      'stores': stores,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    };
  }

  static List<String> _normalizeStores(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .whereType<String>()
          .expand((s) => s.split(','))
          .map((s) => s.normalize())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
    }
    if (raw is String) {
      return raw
          .split(',')
          .map((s) => s.normalize())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
    }
    return const [];
  }
}
