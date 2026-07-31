// lib/features/messaging/models/chat_conversation.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'chat_member_snapshot.dart';

enum ChatConversationStatus {
  open,
  closed;

  String get label {
    return switch (this) {
      ChatConversationStatus.open => 'Open',
      ChatConversationStatus.closed => 'Closed',
    };
  }

  static ChatConversationStatus parse(Object? value) {
    return value?.toString().trim().toLowerCase() == 'closed'
        ? ChatConversationStatus.closed
        : ChatConversationStatus.open;
  }
}

enum ChatSenderRole {
  member,
  staff;

  static ChatSenderRole parse(Object? value) {
    return value?.toString().trim().toLowerCase() == 'staff'
        ? ChatSenderRole.staff
        : ChatSenderRole.member;
  }
}

@immutable
class ChatLastMessage {
  const ChatLastMessage({
    required this.text,
    required this.senderUid,
    required this.senderRole,
    this.sentAt,
  });

  final String text;
  final String senderUid;
  final ChatSenderRole senderRole;
  final DateTime? sentAt;

  factory ChatLastMessage.fromMap(Map<String, dynamic> map) {
    return ChatLastMessage(
      text: _clean(map['text']),
      senderUid: _clean(map['senderUid']),
      senderRole: ChatSenderRole.parse(map['senderRole']),
      sentAt: _readDateTime(map['sentAt']),
    );
  }
}

@immutable
class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.title,
    required this.member,
    required this.status,
    required this.memberUnreadCount,
    required this.staffUnreadCount,
    this.lastMessage,
    this.createdAt,
    this.updatedAt,
    this.closedAt,
    this.closedByUid,
  });

  final String id;
  final String title;
  final ChatMemberSnapshot member;
  final ChatConversationStatus status;
  final ChatLastMessage? lastMessage;
  final int memberUnreadCount;
  final int staffUnreadCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? closedAt;
  final String? closedByUid;

  bool get isOpen => status == ChatConversationStatus.open;

  bool get isClosed => status == ChatConversationStatus.closed;

  bool get hasMemberUnread => memberUnreadCount > 0;

  bool get hasStaffUnread => staffUnreadCount > 0;

  bool get canReceiveMessages => isOpen;

  factory ChatConversation.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return ChatConversation.fromMap(
      id: document.id,
      map: document.data() ?? const <String, dynamic>{},
    );
  }

  factory ChatConversation.fromMap({
    required String id,
    required Map<String, dynamic> map,
  }) {
    final Map<String, dynamic> memberMap = _stringMap(map['member']);
    final Map<String, dynamic>? lastMessageMap = _nullableStringMap(
      map['lastMessage'],
    );

    final String storedTitle = _clean(map['title']);

    return ChatConversation(
      id: id.trim(),
      title: storedTitle.isEmpty ? 'Conversation' : storedTitle,
      member: ChatMemberSnapshot.fromMap(memberMap),
      status: ChatConversationStatus.parse(map['status']),
      lastMessage: lastMessageMap == null
          ? null
          : ChatLastMessage.fromMap(lastMessageMap),
      memberUnreadCount: _readInt(map['memberUnreadCount']),
      staffUnreadCount: _readInt(map['staffUnreadCount']),
      createdAt: _readDateTime(map['createdAt']),
      updatedAt: _readDateTime(map['updatedAt']),
      closedAt: _readDateTime(map['closedAt']),
      closedByUid: _cleanNullable(map['closedByUid']),
    );
  }
}

String _clean(Object? value) {
  return (value ?? '').toString().trim();
}

String? _cleanNullable(Object? value) {
  final String cleaned = _clean(value);

  return cleaned.isEmpty ? null : cleaned;
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(_clean(value)) ?? 0;
}

DateTime? _readDateTime(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}

Map<String, dynamic> _stringMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  return const <String, dynamic>{};
}

Map<String, dynamic>? _nullableStringMap(Object? value) {
  if (value == null) {
    return null;
  }

  final Map<String, dynamic> map = _stringMap(value);

  return map.isEmpty ? null : map;
}
