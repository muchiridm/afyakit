// lib/core/auth/shared/models/auth_user_model.dart
import 'package:flutter/foundation.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth/auth_user/extensions/user_status_x.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_zoho_link.dart';

enum AppMembershipStatus {
  active,
  disabled;

  static AppMembershipStatus? tryParse(Object? raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    return switch (value) {
      'active' => AppMembershipStatus.active,
      'disabled' => AppMembershipStatus.disabled,
      _ => null,
    };
  }

  String get wire => name;
}

@immutable
class AppMembership {
  const AppMembership({required this.status, this.updatedAt});
  final AppMembershipStatus status;
  final String? updatedAt;
  bool get isActive => status == AppMembershipStatus.active;
  static AppMembership? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
    final status = AppMembershipStatus.tryParse(map['status']);
    if (status == null) return null;
    final rawUpdatedAt = map['updatedAt'];
    final updatedAt = rawUpdatedAt?.toString().trim();
    return AppMembership(
      status: status,
      updatedAt: updatedAt == null || updatedAt.isEmpty ? null : updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'status': status.wire,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };
}

/// A verified address for a single app; never a Firebase Auth identity.

@immutable
class AppEmail {
  const AppEmail({required this.emailLower, this.verifiedAt});

  final String emailLower;
  final String? verifiedAt;

  bool get verified => true;

  static AppEmail? tryParse(Object? raw) {
    if (raw is! Map || raw['verified'] != true) return null;

    final email = (raw['emailLower'] ?? '').toString().trim().toLowerCase();

    if (email.isEmpty || !email.contains('@')) return null;

    return AppEmail(
      emailLower: email,
      verifiedAt: raw['verifiedAt']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'emailLower': emailLower,
    'verified': true,
    if (verifiedAt != null) 'verifiedAt': verifiedAt,
  };
}

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
    this.phoneHistory = const [],
    this.phoneVerified = false,
    this.phoneVerifiedAt,
    this.phoneClaimed = false,
    this.phoneClaimedAt,
    this.phoneSatisfied,
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
    List<StaffRole> staffRoles = const [],
    this.staffRolesByApp = const {},
    this.appMembershipsByApp = const {},
    this.emailsByApp = const {},
    this.activeAppId,
    this.recoveryRequired = false,
    this.disabledAt,
    this.disabledReason,
    this.disabledByUid,
    this.createdAt,
    this.updatedAt,
  }) : legacyStaffRoles = staffRoles;
  final String uid;
  final String? phoneNumber;
  final String tenantId;
  final UserStatus status;
  final List<String> stores;
  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? avatarUrl;
  final List<String> phoneHistory;
  final bool phoneVerified;
  final String? phoneVerifiedAt;
  final bool phoneClaimed;
  final String? phoneClaimedAt;
  final bool? phoneSatisfied;
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

  /// Retained for reading old records only; never grants access.
  final List<StaffRole> legacyStaffRoles;
  final Map<String, List<StaffRole>> staffRolesByApp;

  /// Canonical application membership by app.
  /// A user may belong to multiple apps. Membership does not imply staff access.
  final Map<String, AppMembership> appMembershipsByApp;
  final Map<String, AppEmail> emailsByApp;

  AppEmail? emailForApp(String appId) =>
      emailsByApp[appId.trim().toLowerCase()];
  String? get activeAppEmailLower =>
      activeAppId == null ? null : emailForApp(activeAppId!)?.emailLower;

  /// Client context, set by the active-app providers, never trusted from JSON.
  final String? activeAppId;
  List<StaffRole> rolesForApp(String appId) => List<StaffRole>.unmodifiable(
    staffRolesByApp[appId.trim().toLowerCase()] ?? const <StaffRole>[],
  );
  AppMembership? membershipForApp(String appId) {
    final clean = appId.trim().toLowerCase();
    if (clean.isEmpty) return null;
    return appMembershipsByApp[clean];
  }

  bool hasAppMembership(String appId) => membershipForApp(appId) != null;
  bool hasActiveAppMembership(String appId) =>
      membershipForApp(appId)?.isActive == true;
  List<StaffRole> get staffRoles =>
      status == UserStatus.active && activeAppId != null
      ? rolesForApp(activeAppId!)
      : const <StaffRole>[];
  AuthUser forApp(String appId) {
    final clean = appId.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(clean)) {
      throw ArgumentError.value(appId, 'appId', 'Invalid app ID');
    }
    return copyWith(activeAppId: clean);
  }

  static Map<String, AppEmail> _parseAppEmails(Object? raw) {
    if (raw is! Map) return const {};
    final result = <String, AppEmail>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) continue;
      final appId = (entry.key as String).trim().toLowerCase();
      if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(appId)) continue;
      final email = AppEmail.tryParse(entry.value);
      if (email != null) result[appId] = email;
    }
    return Map<String, AppEmail>.unmodifiable(result);
  }

  static Map<String, AppMembership> _parseAppMemberships(Object? raw) {
    if (raw is! Map) return const {};
    final result = <String, AppMembership>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) continue;
      final appId = (entry.key as String).trim().toLowerCase();
      if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(appId)) continue;
      final membership = AppMembership.tryParse(entry.value);
      if (membership == null) continue;
      result[appId] = membership;
    }
    return Map<String, AppMembership>.unmodifiable(result);
  }

  static Map<String, List<StaffRole>> _parseAppRoles(Object? raw) {
    if (raw is! Map) return const {};
    final result = <String, List<StaffRole>>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) continue;
      final key = (entry.key as String).trim().toLowerCase();
      if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(key)) continue;
      result[key] = List<StaffRole>.unmodifiable(
        _normalizeStaffRoles(entry.value),
      );
    }
    return Map<String, List<StaffRole>>.unmodifiable(result);
  }

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

  bool get isStaffResolved => staffRoles.isNotEmpty;
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

  String? get contactId {
    final id = zoho?.contactId.trim();
    if (id == null || id.isEmpty) return null;
    return id;
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

  bool get hasVerifiedEmail => activeAppEmailLower != null;
  String? get bestVerifiedEmailLower => activeAppEmailLower;
  String? get bestEmailForDisplay => activeAppEmailLower;
  String? get bestEmailLower => activeAppEmailLower;
  bool get hasEmail => hasVerifiedEmail;
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
    final isCompany = _bool(json['isCompany']);
    final recoveryRequired = _bool(json['recoveryRequired']);
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
      phoneHistory: _normalizeStringList(json['phoneHistory']),
      phoneVerified: phoneVerified,
      phoneVerifiedAt: _optStr(json['phoneVerifiedAt']),
      phoneClaimed: phoneClaimed,
      phoneClaimedAt: _optStr(json['phoneClaimedAt']),
      phoneSatisfied: phoneSatisfied,
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
      staffRolesByApp: _parseAppRoles(json['staffRolesByApp']),
      appMembershipsByApp: _parseAppMemberships(json['appMembershipsByApp']),
      emailsByApp: _parseAppEmails(json['emailsByApp']),
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
    List<String>? phoneHistory,
    bool? phoneVerified,
    String? phoneVerifiedAt,
    bool? phoneClaimed,
    String? phoneClaimedAt,
    bool? phoneSatisfied,
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
    Map<String, List<StaffRole>>? staffRolesByApp,
    Map<String, AppMembership>? appMembershipsByApp,
    Map<String, AppEmail>? emailsByApp,
    String? activeAppId,
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
      phoneHistory: phoneHistory ?? this.phoneHistory,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      phoneVerifiedAt: phoneVerifiedAt ?? this.phoneVerifiedAt,
      phoneClaimed: phoneClaimed ?? this.phoneClaimed,
      phoneClaimedAt: phoneClaimedAt ?? this.phoneClaimedAt,
      phoneSatisfied: phoneSatisfied ?? this.phoneSatisfied,
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
      staffRoles: staffRoles ?? legacyStaffRoles,
      staffRolesByApp: staffRolesByApp ?? this.staffRolesByApp,
      appMembershipsByApp: appMembershipsByApp ?? this.appMembershipsByApp,
      emailsByApp: emailsByApp ?? this.emailsByApp,
      activeAppId: activeAppId ?? this.activeAppId,
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
    if (phoneHistory.isNotEmpty) 'phoneHistory': phoneHistory,
    if (phoneVerified) 'phoneVerified': true,
    if (phoneVerifiedAt != null) 'phoneVerifiedAt': phoneVerifiedAt,
    if (phoneClaimed) 'phoneClaimed': true,
    if (phoneClaimedAt != null) 'phoneClaimedAt': phoneClaimedAt,
    if (phoneSatisfied != null) 'phoneSatisfied': phoneSatisfied,
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
    'staffRolesByApp': staffRolesByApp.map(
      (appId, roles) =>
          MapEntry(appId, roles.map((r) => r.wire).toList(growable: false)),
    ),
    'emailsByApp': emailsByApp.map(
      (appId, email) => MapEntry(appId, email.toMap()),
    ),
    'appMembershipsByApp': appMembershipsByApp.map(
      (appId, membership) => MapEntry(appId, membership.toMap()),
    ),
    if (recoveryRequired) 'recoveryRequired': true,
    if (disabledAt != null) 'disabledAt': disabledAt,
    if (disabledReason != null) 'disabledReason': disabledReason,
    if (disabledByUid != null) 'disabledByUid': disabledByUid,
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };
}
