// lib/core/auth_users/models/auth_user_model.dart
import 'package:flutter/foundation.dart';
import 'package:afyakit/shared/utils/normalize/normalize_date.dart';
import 'package:afyakit/shared/utils/normalize/normalize_string.dart';

import 'package:afyakit/core/auth_users/extensions/user_status_x.dart';
import 'package:afyakit/core/auth_users/extensions/user_role_x.dart';
import 'package:afyakit/core/auth_users/extensions/user_badge_x.dart';

class AuthUser {
  // ── auth / session fields
  final String uid;
  final String email;
  final String? phoneNumber;
  final UserStatus status; // ✅ enum now
  final String tenantId;
  final DateTime? invitedOn;
  final DateTime? activatedOn;
  final Map<String, dynamic>? claims;

  // ── profile fields
  final String displayName;
  final UserRole role;
  final List<String> stores;
  final String? avatarUrl;

  // ── professional tags (non-authoritative for permissions)
  final List<UserBadge> badges;

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
    this.role = UserRole.client, // safer default for self-signup
    this.stores = const [],
    this.avatarUrl,
    this.badges = const [],
  });

  bool get isSuperAdmin => claims?['superadmin'] == true;

  AuthUser copyWith({
    String? uid,
    String? email,
    String? phoneNumber,
    UserStatus? status,
    String? tenantId,
    DateTime? invitedOn,
    DateTime? activatedOn,
    Map<String, dynamic>? claims,
    String? displayName,
    UserRole? role,
    List<String>? stores,
    String? avatarUrl,
    List<UserBadge>? badges,
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
      badges: badges ?? this.badges,
    );
  }

  // ✅ Prefer top-level fields, fallback to claims.
  factory AuthUser.fromMap(String uid, Map<String, dynamic> json) {
    final Map<String, dynamic>? claims = (json['claims'] is Map)
        ? Map<String, dynamic>.from(json['claims'])
        : null;

    String s(dynamic v) => (v ?? '').toString().trim();

    // email / phone
    final email = s(json['email']);
    final phone = s(json['phoneNumber']).isNotEmpty
        ? s(json['phoneNumber'])
        : (s(claims?['phone']).isNotEmpty
              ? s(claims?['phone'])
              : s(claims?['phone_number']));

    // tenantId (top-level → claims)
    final tenantId = s(json['tenantId']).isNotEmpty
        ? s(json['tenantId'])
        : (s(claims?['tenant']).isNotEmpty
              ? s(claims?['tenant'])
              : (s(claims?['tenantId']).isNotEmpty
                    ? s(claims?['tenantId'])
                    : s(claims?['tenant_id'])));

    // status → enum
    final statusStr = s(json['status']).isNotEmpty
        ? s(json['status'])
        : 'invited';
    final status = UserStatus.fromString(statusStr);

    // role (top-level → claims → default client)
    final rawRole = s(json['role']);
    final claimRole = s(claims?['role']);
    final roleStr = rawRole.isNotEmpty ? rawRole : claimRole;
    final role = UserRole.fromString(roleStr.isNotEmpty ? roleStr : 'client');

    // displayName (top-level → claims.displayName/name)
    final displayName = s(json['displayName']).isNotEmpty
        ? s(json['displayName'])
        : (s(claims?['displayName']).isNotEmpty
              ? s(claims?['displayName'])
              : s(claims?['name']));

    // stores (top-level → claims.stores)
    List<String> storesModel = _normalizeStores(json['stores']);
    final List<String> storesClaims = _normalizeStores(claims?['stores']);
    if (storesModel.isEmpty && storesClaims.isNotEmpty) {
      storesModel = storesClaims;
    }

    // badges (top-level → claims.badges)
    final topBadges = badgesFromAny(json['badges']);
    final claimBadges = badgesFromAny(claims?['badges']);
    final badges = topBadges.isNotEmpty ? topBadges : claimBadges;

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
      avatarUrl: (s(json['avatarUrl']).isNotEmpty)
          ? s(json['avatarUrl'])
          : null,
      badges: badges,
    );

    if (kDebugMode) {
      debugPrint(
        '🧩 [AuthUser.fromMap] uid=${obj.uid} email=${obj.email} '
        'status=${obj.status.wire} role=${obj.role.name} stores=${obj.stores} '
        'badges=${obj.badges.map((b) => b.name).toList()}',
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

  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      AuthUser.fromMap((json['uid'] ?? '').toString(), json);

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phoneNumber': phoneNumber,
      'status': status.wire, // ✅ write as string to Firestore
      'tenantId': tenantId,
      'invitedOn': invitedOn?.toIso8601String(),
      'activatedOn': activatedOn?.toIso8601String(),
      if (claims != null) 'claims': claims,
      'displayName': displayName,
      'role': role.name,
      'stores': stores,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (badges.isNotEmpty) 'badges': badges.map((b) => b.name).toList(),
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
