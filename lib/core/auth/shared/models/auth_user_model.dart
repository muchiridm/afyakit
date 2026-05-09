// lib/core/auth/shared/models/auth_user_model.dart

import 'package:flutter/foundation.dart';

import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth/auth_user/extensions/user_status_x.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_zoho_link.dart';

@immutable
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.tenantId,
    required this.status,
    this.phoneNumber,
    this.stores = const [],
    this.firstName,
    this.lastName,
    this.displayName,
    this.avatarUrl,
    this.email,
    this.emailLower,
    this.emailPendingLower,
    this.emailPendingAt,
    this.emailVerificationRequestedAt,
    this.phoneHistory = const [],
    this.emailHistory = const [],
    this.phoneVerified = false,
    this.phoneVerifiedAt,
    this.phoneClaimed = false,
    this.phoneClaimedAt,
    this.phoneSatisfied,
    this.emailVerified = false,
    this.emailVerifiedAt,
    this.isCompany = false,
    this.companyName,
    this.accountNumber,
    this.previousAccountNumbers = const <String>[],
    this.previousUids = const <String>[],
    this.recoveredFromAccountNumber,
    this.recoveredAt,
    this.zoho,
    this.claims,
    this.isSuperAdmin = false,
    this.staffRoles = const [],
    this.recoveryRequired = false,
    this.disabledAt,
    this.disabledReason,
    this.disabledByUid,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String? phoneNumber;
  final String tenantId;

  final UserStatus status;
  final List<String> stores;

  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? avatarUrl;

  final String? email;
  final String? emailLower;

  final String? emailPendingLower;
  final String? emailPendingAt;
  final String? emailVerificationRequestedAt;

  final List<String> phoneHistory;
  final List<String> emailHistory;

  final bool phoneVerified;
  final String? phoneVerifiedAt;

  final bool phoneClaimed;
  final String? phoneClaimedAt;

  final bool? phoneSatisfied;

  final bool emailVerified;
  final String? emailVerifiedAt;

  final bool isCompany;
  final String? companyName;

  /// Current account number.
  ///
  /// New format:
  ///   AC-XXXXXX
  ///
  /// Legacy numeric values may exist for older/recovered users.
  final String? accountNumber;

  /// Historical account numbers used for recovery/history compatibility.
  final List<String> previousAccountNumbers;

  /// Historical Firebase UIDs associated with recovered identity.
  ///
  /// UID should not be the long-term business identity, but this helps
  /// debug/reconcile old records.
  final List<String> previousUids;

  /// The account number the user entered during recovery.
  final String? recoveredFromAccountNumber;

  /// Recovery success timestamp, ISO string.
  final String? recoveredAt;

  final AuthUserZohoLink? zoho;

  final Map<String, dynamic>? claims;
  final bool isSuperAdmin;
  final List<StaffRole> staffRoles;

  final bool recoveryRequired;

  final String? disabledAt;
  final String? disabledReason;
  final String? disabledByUid;

  final String? createdAt;
  final String? updatedAt;

  static String _cleanStr(Object? v) => (v ?? '').toString().trim();

  static String? _optStr(Object? v) {
    final s = _cleanStr(v);
    return s.isEmpty ? null : s;
  }

  static String? _optUpperStr(Object? v) {
    final s = _cleanStr(v).toUpperCase();
    return s.isEmpty ? null : s;
  }

  static bool _bool(Object? v) => v == true;

  static List<String> _normalizeStores(Object? raw) {
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
    return out.where(seen.add).toList(growable: false);
  }

  static List<String> _normalizeStringList(Object? raw) {
    if (raw is! List) return const <String>[];

    final out = <String>[];

    for (final v in raw) {
      final s = _cleanStr(v);
      if (s.isNotEmpty) out.add(s);
    }

    final seen = <String>{};
    return out.where(seen.add).toList(growable: false);
  }

  static List<String> _normalizeUpperStringList(Object? raw) {
    if (raw is! List) return const <String>[];

    final out = <String>[];

    for (final v in raw) {
      final s = _cleanStr(v).toUpperCase();
      if (s.isNotEmpty) out.add(s);
    }

    final seen = <String>{};
    return out.where(seen.add).toList(growable: false);
  }

  static Map<String, dynamic>? _normalizeClaims(Object? raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }

    return null;
  }

  static List<StaffRole> _normalizeStaffRoles(Object? raw) {
    if (raw is! List) return const <StaffRole>[];

    final out = <StaffRole>[];

    for (final v in raw) {
      final name = _cleanStr(v);
      final parsed = StaffRole.tryParse(name);
      if (parsed != null) out.add(parsed);
    }

    final seen = <String>{};
    return out.where((r) => seen.add(r.name)).toList(growable: false);
  }

  static UserStatus _parseStatus(Object? raw) {
    final s = _cleanStr(raw).toLowerCase();

    try {
      return UserStatus.fromString(s.isEmpty ? 'active' : s);
    } catch (_) {
      return UserStatus.active;
    }
  }

  static bool _isSomaliaPhone(String? phoneE164) =>
      phoneE164 != null && phoneE164.trim().startsWith('+252');

  static bool _computePhoneSatisfied({
    required String? phoneNumber,
    required bool phoneVerified,
    required bool phoneClaimed,
  }) {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) return false;
    if (!_isSomaliaPhone(phoneNumber)) return phoneVerified == true;
    return phoneVerified == true || phoneClaimed == true;
  }

  bool get isStaffResolved => staffRoles.isNotEmpty || isSuperAdmin == true;

  bool get isMemberResolved => !isStaffResolved;

  bool get hasRecoveryTrail {
    return previousAccountNumbers.isNotEmpty ||
        previousUids.isNotEmpty ||
        (recoveredFromAccountNumber ?? '').trim().isNotEmpty ||
        (recoveredAt ?? '').trim().isNotEmpty ||
        (zoho?.previousAccountNumbers.isNotEmpty ?? false);
  }

  List<String> get allKnownAccountNumbers {
    final out = <String>[
      if ((accountNumber ?? '').trim().isNotEmpty) accountNumber!.trim(),
      ...previousAccountNumbers,
      if ((recoveredFromAccountNumber ?? '').trim().isNotEmpty)
        recoveredFromAccountNumber!.trim(),
      ...?zoho?.previousAccountNumbers,
    ];

    final seen = <String>{};
    return out.where((x) => seen.add(x)).toList(growable: false);
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

    final pn = (phoneNumber ?? '').trim();
    if (pn.isNotEmpty) return pn;

    return uid;
  }

  bool get isPhoneSatisfiedResolved {
    final explicit = phoneSatisfied;
    if (explicit != null) return explicit;

    return _computePhoneSatisfied(
      phoneNumber: phoneNumber,
      phoneVerified: phoneVerified,
      phoneClaimed: phoneClaimed,
    );
  }

  bool get hasVerifiedEmail {
    final el = (emailLower ?? '').trim();
    final e = (email ?? '').trim();
    return emailVerified == true && (el.isNotEmpty || e.isNotEmpty);
  }

  bool get hasPendingEmail => (emailPendingLower ?? '').trim().isNotEmpty;

  String? get bestVerifiedEmailLower {
    final el = (emailLower ?? '').trim().toLowerCase();
    if (el.isNotEmpty) return el;

    final e = (email ?? '').trim().toLowerCase();
    return e.isNotEmpty ? e : null;
  }

  String? get bestEmailForDisplay {
    final verified = bestVerifiedEmailLower;
    if (verified != null) return verified;

    final pending = (emailPendingLower ?? '').trim().toLowerCase();
    return pending.isNotEmpty ? pending : null;
  }

  bool get needsEmailVerificationResolved => hasPendingEmail;

  bool get hasEmail => hasVerifiedEmail || hasPendingEmail;

  bool get needsEmailVerification => needsEmailVerificationResolved;

  String? get bestEmailLower {
    final v = bestVerifiedEmailLower;
    if (v != null) return v;

    final p = (emailPendingLower ?? '').trim().toLowerCase();
    return p.isNotEmpty ? p : null;
  }

  bool get isDisabled => status == UserStatus.disabled;

  bool get hasRecoveryRequirement => recoveryRequired == true;

  factory AuthUser.fromMap(Map<String, dynamic> json, {bool allowZoho = true}) {
    final uid = _cleanStr(json['uid']);
    final tenant = _cleanStr(json['tenantId']);

    if (uid.isEmpty) throw ArgumentError('AuthUser requires uid');
    if (tenant.isEmpty) throw ArgumentError('AuthUser requires tenantId');

    final phone = _optStr(json['phoneNumber']);

    final claims = _normalizeClaims(json['claims']);
    final isSuperAdmin = _bool(json['isSuperAdmin']);
    final staffRoles = _normalizeStaffRoles(json['staffRoles']);

    final phoneVerified = _bool(json['phoneVerified']);
    final phoneClaimed = _bool(json['phoneClaimed']);

    final emailVerified = _bool(json['emailVerified']);
    final isCompany = _bool(json['isCompany']);
    final recoveryRequired = _bool(json['recoveryRequired']);

    final emailRaw = _optStr(json['email']);
    final emailLowerRaw = _optStr(json['emailLower']);
    final email = emailRaw?.toLowerCase();
    final emailLower = (emailLowerRaw ?? emailRaw)?.toLowerCase();

    final pendingRaw = _optStr(json['emailPendingLower']);
    final emailPendingLower = pendingRaw?.toLowerCase();
    final emailPendingAt = _optStr(json['emailPendingAt']);
    final emailVerificationRequestedAt = _optStr(
      json['emailVerificationRequestedAt'],
    );

    final phoneSatisfiedRaw = json['phoneSatisfied'];
    final bool? phoneSatisfied = phoneSatisfiedRaw == null
        ? null
        : _bool(phoneSatisfiedRaw);

    final accountNumber =
        _optUpperStr(json['accountNumber']) ??
        _optUpperStr(json['account_number']);

    final previousAccountNumbers = _normalizeUpperStringList(
      json['previousAccountNumbers'],
    );

    final previousUids = _normalizeStringList(json['previousUids']);

    final recoveredFromAccountNumber = _optUpperStr(
      json['recoveredFromAccountNumber'],
    );

    final recoveredAt = _optStr(json['recoveredAt']);

    AuthUserZohoLink? zoho;

    if (allowZoho) {
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
    }

    return AuthUser(
      uid: uid,
      phoneNumber: phone,
      tenantId: tenant,
      status: _parseStatus(json['status']),
      stores: _normalizeStores(json['stores']),
      firstName: _optStr(json['firstName']),
      lastName: _optStr(json['lastName']),
      displayName: _optStr(json['displayName']),
      avatarUrl: _optStr(json['avatarUrl']),
      email: email,
      emailLower: emailLower,
      emailPendingLower: emailPendingLower,
      emailPendingAt: emailPendingAt,
      emailVerificationRequestedAt: emailVerificationRequestedAt,
      phoneHistory: _normalizeStringList(json['phoneHistory']),
      emailHistory: _normalizeStringList(json['emailHistory']),
      phoneVerified: phoneVerified,
      phoneVerifiedAt: _optStr(json['phoneVerifiedAt']),
      phoneClaimed: phoneClaimed,
      phoneClaimedAt: _optStr(json['phoneClaimedAt']),
      phoneSatisfied: phoneSatisfied,
      emailVerified: emailVerified,
      emailVerifiedAt: _optStr(json['emailVerifiedAt']),
      isCompany: isCompany,
      companyName: _optStr(json['companyName']),
      accountNumber: accountNumber,
      previousAccountNumbers: previousAccountNumbers,
      previousUids: previousUids,
      recoveredFromAccountNumber: recoveredFromAccountNumber,
      recoveredAt: recoveredAt,
      zoho: zoho,
      claims: claims,
      isSuperAdmin: isSuperAdmin,
      staffRoles: staffRoles,
      recoveryRequired: recoveryRequired,
      disabledAt: _optStr(json['disabledAt']),
      disabledReason: _optStr(json['disabledReason']),
      disabledByUid: _optStr(json['disabledByUid']),
      createdAt: _optStr(json['createdAt']),
      updatedAt: _optStr(json['updatedAt']),
    );
  }

  factory AuthUser.fromJson(
    Map<String, dynamic> json, {
    bool allowZoho = true,
  }) => AuthUser.fromMap(json, allowZoho: allowZoho);

  AuthUser copyWith({
    UserStatus? status,
    List<String>? stores,
    String? firstName,
    String? lastName,
    String? displayName,
    String? avatarUrl,
    String? email,
    String? emailLower,
    String? emailPendingLower,
    String? emailPendingAt,
    String? emailVerificationRequestedAt,
    List<String>? phoneHistory,
    List<String>? emailHistory,
    bool? phoneVerified,
    String? phoneVerifiedAt,
    bool? phoneClaimed,
    String? phoneClaimedAt,
    bool? phoneSatisfied,
    bool? emailVerified,
    String? emailVerifiedAt,
    bool? isCompany,
    String? companyName,
    String? accountNumber,
    List<String>? previousAccountNumbers,
    List<String>? previousUids,
    String? recoveredFromAccountNumber,
    String? recoveredAt,
    AuthUserZohoLink? zoho,
    Map<String, dynamic>? claims,
    bool? isSuperAdmin,
    List<StaffRole>? staffRoles,
    bool? recoveryRequired,
    String? disabledAt,
    String? disabledReason,
    String? disabledByUid,
    String? createdAt,
    String? updatedAt,
  }) {
    return AuthUser(
      uid: uid,
      phoneNumber: phoneNumber,
      tenantId: tenantId,
      status: status ?? this.status,
      stores: stores ?? this.stores,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      emailLower: emailLower ?? this.emailLower,
      emailPendingLower: emailPendingLower ?? this.emailPendingLower,
      emailPendingAt: emailPendingAt ?? this.emailPendingAt,
      emailVerificationRequestedAt:
          emailVerificationRequestedAt ?? this.emailVerificationRequestedAt,
      phoneHistory: phoneHistory ?? this.phoneHistory,
      emailHistory: emailHistory ?? this.emailHistory,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      phoneVerifiedAt: phoneVerifiedAt ?? this.phoneVerifiedAt,
      phoneClaimed: phoneClaimed ?? this.phoneClaimed,
      phoneClaimedAt: phoneClaimedAt ?? this.phoneClaimedAt,
      phoneSatisfied: phoneSatisfied ?? this.phoneSatisfied,
      emailVerified: emailVerified ?? this.emailVerified,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      isCompany: isCompany ?? this.isCompany,
      companyName: companyName ?? this.companyName,
      accountNumber: accountNumber ?? this.accountNumber,
      previousAccountNumbers:
          previousAccountNumbers ?? this.previousAccountNumbers,
      previousUids: previousUids ?? this.previousUids,
      recoveredFromAccountNumber:
          recoveredFromAccountNumber ?? this.recoveredFromAccountNumber,
      recoveredAt: recoveredAt ?? this.recoveredAt,
      zoho: zoho ?? this.zoho,
      claims: claims ?? this.claims,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      staffRoles: staffRoles ?? this.staffRoles,
      recoveryRequired: recoveryRequired ?? this.recoveryRequired,
      disabledAt: disabledAt ?? this.disabledAt,
      disabledReason: disabledReason ?? this.disabledReason,
      disabledByUid: disabledByUid ?? this.disabledByUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'tenantId': tenantId,
    if (phoneNumber != null) 'phoneNumber': phoneNumber,
    'status': status.wire,
    'stores': stores,
    if (firstName != null) 'firstName': firstName,
    if (lastName != null) 'lastName': lastName,
    if (displayName != null) 'displayName': displayName,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    if (email != null) 'email': email,
    if (emailLower != null) 'emailLower': emailLower,
    if (emailPendingLower != null) 'emailPendingLower': emailPendingLower,
    if (emailPendingAt != null) 'emailPendingAt': emailPendingAt,
    if (emailVerificationRequestedAt != null)
      'emailVerificationRequestedAt': emailVerificationRequestedAt,
    if (phoneHistory.isNotEmpty) 'phoneHistory': phoneHistory,
    if (emailHistory.isNotEmpty) 'emailHistory': emailHistory,
    if (phoneVerified) 'phoneVerified': true,
    if (phoneVerifiedAt != null) 'phoneVerifiedAt': phoneVerifiedAt,
    if (phoneClaimed) 'phoneClaimed': true,
    if (phoneClaimedAt != null) 'phoneClaimedAt': phoneClaimedAt,
    if (phoneSatisfied != null) 'phoneSatisfied': phoneSatisfied,
    if (emailVerified) 'emailVerified': true,
    if (emailVerifiedAt != null) 'emailVerifiedAt': emailVerifiedAt,
    if (isCompany) 'isCompany': true,
    if (companyName != null) 'companyName': companyName,
    if (accountNumber != null) 'accountNumber': accountNumber,
    if (previousAccountNumbers.isNotEmpty)
      'previousAccountNumbers': previousAccountNumbers,
    if (previousUids.isNotEmpty) 'previousUids': previousUids,
    if (recoveredFromAccountNumber != null)
      'recoveredFromAccountNumber': recoveredFromAccountNumber,
    if (recoveredAt != null) 'recoveredAt': recoveredAt,
    if (zoho != null) 'zoho': zoho!.toMap(),
    if (claims != null && claims!.isNotEmpty) 'claims': claims,
    if (isSuperAdmin) 'isSuperAdmin': true,
    if (staffRoles.isNotEmpty)
      'staffRoles': staffRoles.map((r) => r.name).toList(growable: false),
    if (recoveryRequired) 'recoveryRequired': true,
    if (disabledAt != null) 'disabledAt': disabledAt,
    if (disabledReason != null) 'disabledReason': disabledReason,
    if (disabledByUid != null) 'disabledByUid': disabledByUid,
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };
}
