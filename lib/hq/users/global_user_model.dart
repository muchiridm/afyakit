// lib/users/models/global_user.dart

import 'package:afyakit/shared/utils/firestore_instance.dart';

/// Prefer strict typing over `dynamic`.
typedef Json = Map<String, Object?>;

/// Canonical profile for a Firebase Auth user mirrored in Firestore at:
///   users/{uid}
///
/// Keep this doc skinny. Per-tenant roles/memberships live under:
///   users/{uid}/memberships/{tenantId}
class GlobalUser {
  final String id; // uid (doc id)
  final String? email; // may be null if provider didn’t supply
  final String emailLower; // normalized for lookups
  final String? displayName;
  final String? photoURL;
  final String? phoneNumber;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final bool disabled;

  const GlobalUser({
    required this.id,
    required this.emailLower,
    this.email,
    this.displayName,
    this.photoURL,
    this.phoneNumber,
    this.createdAt,
    this.lastLoginAt,
    this.disabled = false,
  });

  /// Safe factory from Firestore JSON (values are Object?; no `dynamic` usage).
  factory GlobalUser.fromJson(String id, Json j) {
    return GlobalUser(
      id: id,
      email: _readString(j['email']),
      emailLower: _normalizeLower(
        _readString(j['emailLower']) ?? _readString(j['email']) ?? '',
      ),
      displayName: _readString(j['displayName']),
      photoURL: _readString(j['photoURL']),
      phoneNumber: _readString(j['phoneNumber']),
      createdAt: _readDateTime(j['createdAt']),
      lastLoginAt: _readDateTime(j['lastLoginAt']),
      disabled: _readBool(j['disabled']) ?? false,
    );
  }

  /// JSON ready for Firestore. Never writes null for `emailLower`.
  Json toJson() {
    return <String, Object?>{
      'email': email,
      'emailLower': emailLower.isEmpty
          ? (email ?? '').toLowerCase()
          : emailLower,
      'displayName': displayName,
      'photoURL': photoURL,
      'phoneNumber': phoneNumber,
      'createdAt':
          createdAt, // Firestore accepts DateTime; serverTimestamp set by caller
      'lastLoginAt': lastLoginAt,
      'disabled': disabled,
    };
  }

  GlobalUser copyWith({
    String? id,
    String? email,
    String? emailLower,
    String? displayName,
    String? photoURL,
    String? phoneNumber,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? disabled,
  }) {
    return GlobalUser(
      id: id ?? this.id,
      email: email ?? this.email,
      emailLower: emailLower != null && emailLower.isNotEmpty
          ? _normalizeLower(emailLower)
          : this.emailLower,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      disabled: disabled ?? this.disabled,
    );
  }

  @override
  String toString() =>
      'GlobalUser(id: $id, email: $email, disabled: $disabled)';

  @override
  bool operator ==(Object other) {
    return other is GlobalUser &&
        other.id == id &&
        other.email == email &&
        other.emailLower == emailLower &&
        other.displayName == displayName &&
        other.photoURL == photoURL &&
        other.phoneNumber == phoneNumber &&
        other.disabled == disabled &&
        _eqDate(other.createdAt, createdAt) &&
        _eqDate(other.lastLoginAt, lastLoginAt);
  }

  @override
  int get hashCode =>
      id.hashCode ^
      (email ?? '').hashCode ^
      emailLower.hashCode ^
      (displayName ?? '').hashCode ^
      (photoURL ?? '').hashCode ^
      (phoneNumber ?? '').hashCode ^
      disabled.hashCode ^
      (createdAt?.millisecondsSinceEpoch ?? 0) ^
      (lastLoginAt?.millisecondsSinceEpoch ?? 0);
}

/// ─────────────────────────────────────────────────────────────
/// Helpers (no `dynamic` — only type guards on Object?)
/// ─────────────────────────────────────────────────────────────
String? _readString(Object? v) => v is String ? v : null;
bool? _readBool(Object? v) => v is bool ? v : null;

DateTime? _readDateTime(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is String) {
    // ISO 8601 support if you ever serialize as string
    final parsed = DateTime.tryParse(v);
    return parsed;
  }
  return null;
}

bool _eqDate(DateTime? a, DateTime? b) => a?.toUtc() == b?.toUtc();

String _normalizeLower(String input) => input.trim().toLowerCase();
