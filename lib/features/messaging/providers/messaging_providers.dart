// lib/features/messaging/providers/messaging_providers.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';

import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../repositories/messaging_repository.dart';

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  return MessagingRepository(FirebaseFirestore.instance);
});

final staffChatConversationsProvider =
    StreamProvider.autoDispose<List<ChatConversation>>((ref) {
      final String tenantId = ref.watch(tenantIdProvider);
      final repository = ref.watch(messagingRepositoryProvider);

      return repository.watchStaffConversations(tenantId: tenantId);
    });

final memberChatConversationsProvider = StreamProvider.autoDispose
    .family<List<ChatConversation>, String>((ref, memberUid) {
      final String uid = memberUid.trim();

      if (uid.isEmpty) {
        return Stream<List<ChatConversation>>.value(const <ChatConversation>[]);
      }

      final String tenantId = ref.watch(tenantIdProvider);
      final repository = ref.watch(messagingRepositoryProvider);

      return repository.watchMemberConversations(
        tenantId: tenantId,
        memberUid: uid,
      );
    });

final chatConversationProvider = StreamProvider.autoDispose
    .family<ChatConversation?, String>((ref, conversationId) {
      final String id = conversationId.trim();

      if (id.isEmpty) {
        return Stream<ChatConversation?>.value(null);
      }

      final String tenantId = ref.watch(tenantIdProvider);
      final repository = ref.watch(messagingRepositoryProvider);

      return repository.watchConversation(
        tenantId: tenantId,
        conversationId: id,
      );
    });

@immutable
class ChatMessagesScope {
  const ChatMessagesScope({required this.conversationId});

  final String conversationId;

  String get normalizedConversationId => conversationId.trim();

  bool get isValid => normalizedConversationId.isNotEmpty;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChatMessagesScope &&
            other.normalizedConversationId == normalizedConversationId;
  }

  @override
  int get hashCode => normalizedConversationId.hashCode;
}

final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, ChatMessagesScope>((ref, scope) {
      if (!scope.isValid) {
        return Stream<List<ChatMessage>>.value(const <ChatMessage>[]);
      }

      final String tenantId = ref.watch(tenantIdProvider);
      final repository = ref.watch(messagingRepositoryProvider);

      return repository.watchMessages(
        tenantId: tenantId,
        conversationId: scope.normalizedConversationId,
      );
    });

final memberUnreadMessagesProvider = Provider.autoDispose.family<int, String>((
  ref,
  memberUid,
) {
  final AsyncValue<List<ChatConversation>> conversationsAsync = ref.watch(
    memberChatConversationsProvider(memberUid),
  );

  return conversationsAsync.maybeWhen(
    data: (conversations) {
      return conversations.fold<int>(
        0,
        (total, conversation) => total + conversation.memberUnreadCount,
      );
    },
    orElse: () => 0,
  );
});

final staffUnreadMessagesProvider = Provider.autoDispose<int>((ref) {
  final AsyncValue<List<ChatConversation>> conversationsAsync = ref.watch(
    staffChatConversationsProvider,
  );

  return conversationsAsync.maybeWhen(
    data: (conversations) {
      return conversations.fold<int>(
        0,
        (total, conversation) => total + conversation.staffUnreadCount,
      );
    },
    orElse: () => 0,
  );
});
