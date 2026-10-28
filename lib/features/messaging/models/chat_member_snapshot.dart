// lib/features/messaging/models/chat_member_snapshot.dart

import 'package:flutter/foundation.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

@immutable
class ChatMemberSnapshot {
  const ChatMemberSnapshot({
    required this.uid,
    required this.name,
    this.accountNumber,
    this.phoneNumber,
  });

  /// Firebase authentication identity.
  final String uid;

  /// Display-name snapshot for messaging.
  /// Resolved from Native Contact through session identity.
  final String name;

  /// Canonical Native Contact reference (AC-XXXXXX).
  final String? accountNumber;

  /// Login phone, not the canonical contact phone.
  final String? phoneNumber;

  factory ChatMemberSnapshot.fromUser(AuthUser user) {
    final displayName = user.identity?.displayName?.trim() ?? '';

    return ChatMemberSnapshot(
      uid: user.uid.trim(),
      name: displayName.isNotEmpty ? displayName : user.uid.trim(),
      accountNumber: _cleanNullable(user.accountNumber),
      phoneNumber: _cleanNullable(user.phoneNumber),
    );
  }

  factory ChatMemberSnapshot.fromMap(Map<String, dynamic> map) {
    return ChatMemberSnapshot(
      uid: _clean(map['uid']),
      name: _clean(map['name']),
      accountNumber: _cleanNullable(map['accountNumber']),
      phoneNumber: _cleanNullable(map['phoneNumber']),
    );
  }

  ChatMemberSnapshot copyWith({
    String? uid,
    String? name,
    String? accountNumber,
    String? phoneNumber,
  }) {
    return ChatMemberSnapshot(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      accountNumber: accountNumber ?? this.accountNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'name': name,
      if (accountNumber != null) 'accountNumber': accountNumber,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
    };
  }

  static String _clean(Object? value) {
    return (value ?? '').toString().trim();
  }

  static String? _cleanNullable(Object? value) {
    final cleaned = _clean(value);
    return cleaned.isEmpty ? null : cleaned;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChatMemberSnapshot &&
            other.uid == uid &&
            other.name == name &&
            other.accountNumber == accountNumber &&
            other.phoneNumber == phoneNumber;
  }

  @override
  int get hashCode {
    return Object.hash(uid, name, accountNumber, phoneNumber);
  }
}
