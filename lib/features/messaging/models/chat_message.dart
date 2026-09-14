// lib/features/messaging/models/chat_message.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'chat_conversation.dart';

enum ChatMessageType {
  text;

  static ChatMessageType parse(Object? value) {
    return ChatMessageType.text;
  }
}

@immutable
class ChatMessageSender {
  const ChatMessageSender({
    required this.uid,
    required this.name,
    required this.role,
  });

  final String uid;
  final String name;
  final ChatSenderRole role;

  factory ChatMessageSender.fromMap(Map<String, dynamic> map) {
    return ChatMessageSender(
      uid: _clean(map['uid']),
      name: _clean(map['name']),
      role: ChatSenderRole.parse(map['role']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'uid': uid, 'name': name, 'role': role.name};
  }

  static String _clean(Object? value) {
    return (value ?? '').toString().trim();
  }
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.type,
    required this.text,
    this.createdAt,
  });

  final String id;
  final ChatMessageSender sender;
  final ChatMessageType type;
  final String text;
  final DateTime? createdAt;

  factory ChatMessage.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? const <String, dynamic>{};

    return ChatMessage.fromMap(id: document.id, map: data);
  }

  factory ChatMessage.fromMap({
    required String id,
    required Map<String, dynamic> map,
  }) {
    return ChatMessage(
      id: id.trim(),
      sender: ChatMessageSender.fromMap(_stringMap(map['sender'])),
      type: ChatMessageType.parse(map['type']),
      text: (map['text'] ?? '').toString().trim(),
      createdAt: _readDateTime(map['createdAt']),
    );
  }

  bool isMine(String uid) {
    return sender.uid == uid.trim();
  }

  static DateTime? _readDateTime(Object? value) {
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

  static Map<String, dynamic> _stringMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map(
        (Object? key, Object? item) => MapEntry(key.toString(), item),
      );
    }

    return const <String, dynamic>{};
  }
}
