// lib/features/messaging/repositories/messaging_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

import '../models/chat_conversation.dart';
import '../models/chat_member_snapshot.dart';
import '../models/chat_message.dart';

class MessagingRepository {
  MessagingRepository(this._firestore);

  final FirebaseFirestore _firestore;

  static const int maxMessageLength = 4000;
  static const int maxTitleLength = 60;

  CollectionReference<Map<String, dynamic>> _conversationsRef(String tenantId) {
    return _firestore
        .collection('tenants')
        .doc(_requireValue(tenantId, 'tenantId'))
        .collection('conversations');
  }

  DocumentReference<Map<String, dynamic>> _conversationRef({
    required String tenantId,
    required String conversationId,
  }) {
    return _conversationsRef(
      tenantId,
    ).doc(_requireValue(conversationId, 'conversationId'));
  }

  CollectionReference<Map<String, dynamic>> _messagesRef({
    required String tenantId,
    required String conversationId,
  }) {
    return _conversationRef(
      tenantId: tenantId,
      conversationId: conversationId,
    ).collection('messages');
  }

  Stream<List<ChatConversation>> watchMemberConversations({
    required String tenantId,
    required String memberUid,
  }) {
    final String uid = _requireValue(memberUid, 'memberUid');

    return _conversationsRef(tenantId)
        .where('member.uid', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ChatConversation.fromDocument)
              .toList(growable: false),
        );
  }

  Stream<List<ChatConversation>> watchStaffConversations({
    required String tenantId,
  }) {
    return _conversationsRef(tenantId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ChatConversation.fromDocument)
              .toList(growable: false),
        );
  }

  Stream<ChatConversation?> watchConversation({
    required String tenantId,
    required String conversationId,
  }) {
    return _conversationRef(
      tenantId: tenantId,
      conversationId: conversationId,
    ).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      return ChatConversation.fromDocument(snapshot);
    });
  }

  Stream<List<ChatMessage>> watchMessages({
    required String tenantId,
    required String conversationId,
  }) {
    return _messagesRef(tenantId: tenantId, conversationId: conversationId)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ChatMessage.fromDocument)
              .toList(growable: false),
        );
  }

  Future<String> createConversation({
    required String tenantId,
    required AuthUser user,
    required String firstMessage,
  }) async {
    final String text = _validateMessage(firstMessage);
    final ChatMemberSnapshot member = ChatMemberSnapshot.fromUser(user);

    if (member.uid.isEmpty) {
      throw StateError('Cannot create a conversation without a member UID.');
    }

    final String senderName = user.computedDisplayName.trim().isEmpty
        ? member.uid
        : user.computedDisplayName.trim();

    final DocumentReference<Map<String, dynamic>> conversationRef =
        _conversationsRef(tenantId).doc();

    final DocumentReference<Map<String, dynamic>> messageRef = conversationRef
        .collection('messages')
        .doc();

    final WriteBatch batch = _firestore.batch();

    batch.set(conversationRef, <String, dynamic>{
      'title': composeConversationTitle(text),
      'member': member.toMap(),
      'status': ChatConversationStatus.open.name,
      'memberUnreadCount': 0,
      'staffUnreadCount': 1,
      'lastMessage': <String, dynamic>{
        'text': text,
        'senderUid': member.uid,
        'senderRole': ChatSenderRole.member.name,
        'sentAt': FieldValue.serverTimestamp(),
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(messageRef, <String, dynamic>{
      'sender': <String, dynamic>{
        'uid': member.uid,
        'name': senderName,
        'role': ChatSenderRole.member.name,
      },
      'type': ChatMessageType.text.name,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return conversationRef.id;
  }

  Future<void> sendMemberMessage({
    required String tenantId,
    required String conversationId,
    required AuthUser user,
    required String text,
  }) async {
    await _sendMessage(
      tenantId: tenantId,
      conversationId: conversationId,
      senderUid: user.uid,
      senderName: user.computedDisplayName,
      senderRole: ChatSenderRole.member,
      text: _validateMessage(text),
      member: ChatMemberSnapshot.fromUser(user),
    );
  }

  Future<void> sendStaffMessage({
    required String tenantId,
    required String conversationId,
    required AuthUser user,
    required String text,
  }) async {
    await _sendMessage(
      tenantId: tenantId,
      conversationId: conversationId,
      senderUid: user.uid,
      senderName: user.computedDisplayName,
      senderRole: ChatSenderRole.staff,
      text: _validateMessage(text),
    );
  }

  Future<void> _sendMessage({
    required String tenantId,
    required String conversationId,
    required String senderUid,
    required String senderName,
    required ChatSenderRole senderRole,
    required String text,
    ChatMemberSnapshot? member,
  }) async {
    final DocumentReference<Map<String, dynamic>> conversationRef =
        _conversationRef(tenantId: tenantId, conversationId: conversationId);

    final DocumentReference<Map<String, dynamic>> messageRef = _messagesRef(
      tenantId: tenantId,
      conversationId: conversationId,
    ).doc();

    await _firestore.runTransaction<void>((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> conversationSnapshot =
          await transaction.get(conversationRef);

      if (!conversationSnapshot.exists) {
        throw StateError('This conversation no longer exists.');
      }

      final ChatConversation conversation = ChatConversation.fromDocument(
        conversationSnapshot,
      );

      if (conversation.isClosed) {
        throw StateError(
          'This conversation is closed. Reopen it before sending a message.',
        );
      }

      final String cleanSenderUid = _requireValue(senderUid, 'senderUid');

      final String cleanSenderName = senderName.trim().isEmpty
          ? cleanSenderUid
          : senderName.trim();

      transaction.set(messageRef, <String, dynamic>{
        'sender': <String, dynamic>{
          'uid': cleanSenderUid,
          'name': cleanSenderName,
          'role': senderRole.name,
        },
        'type': ChatMessageType.text.name,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final Map<String, dynamic> conversationUpdate = <String, dynamic>{
        'lastMessage': <String, dynamic>{
          'text': text,
          'senderUid': cleanSenderUid,
          'senderRole': senderRole.name,
          'sentAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (senderRole == ChatSenderRole.member) {
        conversationUpdate.addAll(<String, dynamic>{
          'memberUnreadCount': 0,
          'staffUnreadCount': FieldValue.increment(1),
          if (member != null) 'member': member.toMap(),
        });
      } else {
        conversationUpdate.addAll(<String, dynamic>{
          'memberUnreadCount': FieldValue.increment(1),
          'staffUnreadCount': 0,
        });
      }

      transaction.update(conversationRef, conversationUpdate);
    });
  }

  Future<void> markMemberConversationRead({
    required String tenantId,
    required String conversationId,
  }) async {
    await _updateExistingConversation(
      tenantId: tenantId,
      conversationId: conversationId,
      values: <String, dynamic>{'memberUnreadCount': 0},
    );
  }

  Future<void> markStaffConversationRead({
    required String tenantId,
    required String conversationId,
  }) async {
    await _updateExistingConversation(
      tenantId: tenantId,
      conversationId: conversationId,
      values: <String, dynamic>{'staffUnreadCount': 0},
    );
  }

  Future<void> setConversationStatus({
    required String tenantId,
    required String conversationId,
    required ChatConversationStatus status,
    required AuthUser user,
  }) async {
    final Map<String, dynamic> values = <String, dynamic>{
      'status': status.name,
    };

    if (status == ChatConversationStatus.closed) {
      values.addAll(<String, dynamic>{
        'closedAt': FieldValue.serverTimestamp(),
        'closedByUid': user.uid,
      });
    } else {
      values.addAll(<String, dynamic>{
        'closedAt': FieldValue.delete(),
        'closedByUid': FieldValue.delete(),
      });
    }

    await _updateExistingConversation(
      tenantId: tenantId,
      conversationId: conversationId,
      values: values,
    );
  }

  Future<void> _updateExistingConversation({
    required String tenantId,
    required String conversationId,
    required Map<String, dynamic> values,
  }) async {
    final DocumentReference<Map<String, dynamic>> reference = _conversationRef(
      tenantId: tenantId,
      conversationId: conversationId,
    );

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await reference
        .get();

    if (!snapshot.exists) {
      return;
    }

    await reference.update(<String, dynamic>{
      ...values,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String composeConversationTitle(String message) {
    final String cleaned = message.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (cleaned.isEmpty) {
      return 'New conversation';
    }

    if (cleaned.length <= maxTitleLength) {
      return cleaned;
    }

    final String shortened = cleaned.substring(0, maxTitleLength);

    final int lastSpace = shortened.lastIndexOf(' ');

    final String title = lastSpace > 30
        ? shortened.substring(0, lastSpace)
        : shortened;

    return '$title…';
  }

  String _validateMessage(String text) {
    final String clean = text.trim();

    if (clean.isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }

    if (clean.length > maxMessageLength) {
      throw ArgumentError(
        'Message cannot exceed $maxMessageLength characters.',
      );
    }

    return clean;
  }

  static String _requireValue(String value, String fieldName) {
    final String clean = value.trim();

    if (clean.isEmpty) {
      throw ArgumentError('$fieldName cannot be empty.');
    }

    return clean;
  }
}
