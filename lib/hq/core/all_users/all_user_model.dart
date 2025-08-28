// lib/hq/core/all_users/all_user_model.dart

import 'package:afyakit/shared/utils/firestore_instance.dart';

typedef Json = Map<String, Object?>;

class AllUser {
  final String id;
  final String? email;
  final String emailLower;
  final String? displayName;
  final String? photoURL;
  final String? phoneNumber;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final bool disabled;

  // Cached, not authoritative:
  final List<String> tenantIds; // derived from memberships
  final int tenantCount; // derived from tenantIds length

  const AllUser({
    required this.id,
    required this.emailLower,
    this.email,
    this.displayName,
    this.photoURL,
    this.phoneNumber,
    this.createdAt,
    this.lastLoginAt,
    this.disabled = false,
    this.tenantIds = const [],
    this.tenantCount = 0,
  });

  factory AllUser.fromJson(String id, Json j) {
    final ids = _readStringList(j['tenantIds']) ?? const <String>[];
    final count = _readInt(j['tenantCount']) ?? ids.length;
    return AllUser(
      id: id,
      email: _s(j['email']),
      emailLower: _norm(_s(j['emailLower']) ?? _s(j['email']) ?? ''),
      displayName: _s(j['displayName']),
      photoURL: _s(j['photoURL']),
      phoneNumber: _s(j['phoneNumber']),
      createdAt: _dt(j['createdAt']),
      lastLoginAt: _dt(j['lastLoginAt']),
      disabled: _b(j['disabled']) ?? false,
      tenantIds: ids,
      tenantCount: count,
    );
  }

  Json toJson() => <String, Object?>{
    'email': email,
    'emailLower': emailLower.isEmpty ? (email ?? '').toLowerCase() : emailLower,
    'displayName': displayName,
    'photoURL': photoURL,
    'phoneNumber': phoneNumber,
    'createdAt': createdAt,
    'lastLoginAt': lastLoginAt,
    'disabled': disabled,
    'tenantIds': tenantIds,
    'tenantCount': tenantCount,
  };
}

// helpers
String? _s(Object? v) => v is String ? v : null;
bool? _b(Object? v) => v is bool ? v : null;
int? _readInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
DateTime? _dt(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v);
  return null;
}

List<String>? _readStringList(Object? v) {
  if (v is List) {
    final out = <String>[];
    for (final e in v) {
      if (e is String) out.add(e);
    }
    return out;
  }
  return null;
}

String _norm(String s) => s.trim().toLowerCase();
