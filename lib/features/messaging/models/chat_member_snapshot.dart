// lib/features/messaging/models/chat_member_snapshot.dart

import 'package:flutter/foundation.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

@immutable
class ChatMemberSnapshot {
  const ChatMemberSnapshot({
    required this.uid,
    required this.name,
    this.contactId,
    this.accountNumber,
    this.phoneNumber,
  });

  final String uid;
  final String name;
  final String? contactId;
  final String? accountNumber;
  final String? phoneNumber;

  factory ChatMemberSnapshot.fromUser(AuthUser user) {
    return ChatMemberSnapshot(
      uid: user.uid.trim(),
      name: user.computedDisplayName.trim(),
      contactId: _cleanNullable(user.contactId),
      accountNumber: _cleanNullable(user.accountNumber),
      phoneNumber: _cleanNullable(user.phoneNumber),
    );
  }

  factory ChatMemberSnapshot.fromMap(Map<String, dynamic> map) {
    return ChatMemberSnapshot(
      uid: _clean(map['uid']),
      name: _clean(map['name']),
      contactId: _cleanNullable(map['contactId']),
      accountNumber: _cleanNullable(map['accountNumber']),
      phoneNumber: _cleanNullable(map['phoneNumber']),
    );
  }

  ChatMemberSnapshot copyWith({
    String? uid,
    String? name,
    String? contactId,
    String? accountNumber,
    String? phoneNumber,
  }) {
    return ChatMemberSnapshot(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      contactId: contactId ?? this.contactId,
      accountNumber: accountNumber ?? this.accountNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'name': name,
      if (contactId != null) 'contactId': contactId,
      if (accountNumber != null) 'accountNumber': accountNumber,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
    };
  }

  static String _clean(Object? value) {
    return (value ?? '').toString().trim();
  }

  static String? _cleanNullable(Object? value) {
    final String cleaned = _clean(value);

    return cleaned.isEmpty ? null : cleaned;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChatMemberSnapshot &&
            other.uid == uid &&
            other.name == name &&
            other.contactId == contactId &&
            other.accountNumber == accountNumber &&
            other.phoneNumber == phoneNumber;
  }

  @override
  int get hashCode {
    return Object.hash(uid, name, contactId, accountNumber, phoneNumber);
  }
}
