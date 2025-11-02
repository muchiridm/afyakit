// lib/core/auth_users/models/auth_user_model.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

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
    this.role = UserRole.client,
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

  /// Main factory.
  ///
  /// - `uid` → from API first, else from `fbUser`, else throw
  /// - `email` / `phone` → API → claims → Firebase → throw if both missing
  /// - `tenantId` → API → claims → fallbackTenantId → throw
  factory AuthUser.fromMap(
    String uid,
    Map<String, dynamic> json, {
    fb.User? fbUser,
    String? fallbackTenantId,
  }) {
    final Map<String, dynamic>? claims = (json['claims'] is Map)
        ? Map<String, dynamic>.from(json['claims'])
        : null;

    String s(dynamic v) => (v ?? '').toString().trim();

    // ── UID
    // API may send empty uid; prefer a real one from Firebase if so
    final apiUid = s(uid);
    final fbUid = fbUser?.uid.trim();
    final finalUid = apiUid.isNotEmpty ? apiUid : (fbUid ?? '');
    if (finalUid.isEmpty) {
      throw ArgumentError('❌ AuthUser must have a uid (API or Firebase).');
    }

    // ── email / phone
    final apiEmail = s(json['email']);
    final claimsEmail = s(claims?['email']);
    final fbEmail = fbUser?.email?.trim() ?? '';

    final email = apiEmail.isNotEmpty
        ? apiEmail
        : (claimsEmail.isNotEmpty ? claimsEmail : fbEmail);

    final apiPhone = s(json['phoneNumber']);
    final claimsPhone = s(claims?['phone']).isNotEmpty
        ? s(claims?['phone'])
        : s(claims?['phone_number']);
    final fbPhone = fbUser?.phoneNumber?.trim() ?? '';

    final phone = apiPhone.isNotEmpty
        ? apiPhone
        : (claimsPhone.isNotEmpty ? claimsPhone : fbPhone);

    // ── tenantId (API → claims → fallbackTenantId)
    final apiTenant = s(json['tenantId']);
    final claimsTenant = s(claims?['tenant']).isNotEmpty
        ? s(claims?['tenant'])
        : (s(claims?['tenantId']).isNotEmpty
              ? s(claims?['tenantId'])
              : s(claims?['tenant_id']));
    final tenantId = apiTenant.isNotEmpty
        ? apiTenant
        : (claimsTenant.isNotEmpty ? claimsTenant : (fallbackTenantId ?? ''));

    // ── status → enum
    final statusStr = s(json['status']).isNotEmpty
        ? s(json['status'])
        : 'invited';
    final status = UserStatus.fromString(statusStr);

    // ── role (API → claims → default)
    final rawRole = s(json['role']);
    final claimRole = s(claims?['role']);
    final roleStr = rawRole.isNotEmpty ? rawRole : claimRole;
    final role = UserRole.fromString(roleStr.isNotEmpty ? roleStr : 'client');

    // ── displayName
    final displayName = s(json['displayName']).isNotEmpty
        ? s(json['displayName'])
        : (s(claims?['displayName']).isNotEmpty
              ? s(claims?['displayName'])
              : s(claims?['name']));

    // ── stores (API → claims)
    List<String> storesModel = _normalizeStores(json['stores']);
    final List<String> storesClaims = _normalizeStores(claims?['stores']);
    if (storesModel.isEmpty && storesClaims.isNotEmpty) {
      storesModel = storesClaims;
    }

    // ── badges (API → claims)
    final topBadges = badgesFromAny(json['badges']);
    final claimBadges = badgesFromAny(claims?['badges']);
    final badges = topBadges.isNotEmpty ? topBadges : claimBadges;

    final user = AuthUser(
      uid: finalUid,
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
        '🧩 [AuthUser.fromMap] uid=${user.uid} email=${user.email} '
        'status=${user.status.wire} role=${user.role.name} tenant=${user.tenantId} '
        'stores=${user.stores} badges=${user.badges.map((b) => b.name).toList()}',
      );
    }

    // ── invariants (after merging Firebase!)
    final hasEmail = user.email.trim().isNotEmpty;
    final hasPhone = user.phoneNumber?.trim().isNotEmpty == true;
    if (!hasEmail && !hasPhone) {
      throw ArgumentError(
        '❌ AuthUser must have at least an email or phone number (API+claims+Firebase all empty).',
      );
    }
    if (user.tenantId.trim().isEmpty) {
      throw ArgumentError(
        '❌ AuthUser must have a valid tenantId (API/claims/fallback).',
      );
    }

    return user;
  }

  /// Keep backward compat but now it can’t merge Firebase.
  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      AuthUser.fromMap((json['uid'] ?? '').toString(), json);

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phoneNumber': phoneNumber,
      'status': status.wire,
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
