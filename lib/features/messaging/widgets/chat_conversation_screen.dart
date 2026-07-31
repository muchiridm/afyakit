// lib/features/messaging/widgets/chat_conversation_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/utils/app_error_message.dart';
import 'package:afyakit/shared/widgets/app_error_pane.dart';

import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../providers/messaging_providers.dart';
import 'chat_composer.dart';
import 'chat_message_bubble.dart';

class ChatConversationScreen extends ConsumerStatefulWidget {
  const ChatConversationScreen({
    super.key,
    required this.conversationId,
    required this.user,
    required this.title,
    required this.senderRole,
  });

  final String conversationId;
  final AuthUser user;
  final String title;
  final ChatSenderRole senderRole;

  @override
  ConsumerState<ChatConversationScreen> createState() {
    return _ChatConversationScreenState();
  }
}

class _ChatConversationScreenState
    extends ConsumerState<ChatConversationScreen> {
  static const double _chatMaxWidth = 760;

  final ScrollController _scrollController = ScrollController();

  bool _markReadScheduled = false;
  int _previousMessageCount = 0;

  ChatMessagesScope get _scope {
    return ChatMessagesScope(conversationId: widget.conversationId);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleMarkRead() {
    if (_markReadScheduled) {
      return;
    }

    _markReadScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      try {
        await _markRead();
      } finally {
        _markReadScheduled = false;
      }
    });
  }

  Future<void> _markRead() async {
    final String tenantId = ref.read(tenantIdProvider);
    final repository = ref.read(messagingRepositoryProvider);

    switch (widget.senderRole) {
      case ChatSenderRole.member:
        await repository.markMemberConversationRead(
          tenantId: tenantId,
          conversationId: widget.conversationId,
        );
        break;

      case ChatSenderRole.staff:
        await repository.markStaffConversationRead(
          tenantId: tenantId,
          conversationId: widget.conversationId,
        );
        break;
    }
  }

  Future<void> _sendMessage(String text) async {
    final String tenantId = ref.read(tenantIdProvider);
    final repository = ref.read(messagingRepositoryProvider);

    try {
      switch (widget.senderRole) {
        case ChatSenderRole.member:
          await repository.sendMemberMessage(
            tenantId: tenantId,
            conversationId: widget.conversationId,
            user: widget.user,
            text: text,
          );
          break;

        case ChatSenderRole.staff:
          await repository.sendStaffMessage(
            tenantId: tenantId,
            conversationId: widget.conversationId,
            user: widget.user,
            text: text,
          );
          break;
      }

      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              appErrorMessage(
                error,
                fallback: 'We could not send your message.',
              ),
            ),
          ),
        );

      rethrow;
    }
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final double destination = _scrollController.position.maxScrollExtent;

      if (!animate) {
        _scrollController.jumpTo(destination);
        return;
      }

      _scrollController.animateTo(
        destination,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ChatMessage>> messagesAsync = ref.watch(
      chatMessagesProvider(_scope),
    );

    messagesAsync.whenData((messages) {
      _scheduleMarkRead();

      if (messages.length != _previousMessageCount) {
        final bool firstLoad = _previousMessageCount == 0;

        _previousMessageCount = messages.length;

        if (messages.isNotEmpty) {
          _scrollToBottom(animate: !firstLoad);
        }
      }
    });

    return AppPage(
      title: widget.title,
      showBack: true,
      scrollable: false,
      maxWidth: _chatMaxWidth,
      padding: EdgeInsets.zero,
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.symmetric(
            vertical: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.22),
            ),
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: AppErrorPane(
                    title: 'Messages unavailable',
                    message: appErrorMessage(
                      error,
                      fallback:
                          'We could not load this conversation right now.',
                    ),
                  ),
                ),
                data: (messages) {
                  if (messages.isEmpty) {
                    return _EmptyConversation(viewerRole: widget.senderRole);
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return ChatMessageBubble(
                        message: messages[index],
                        viewerRole: widget.senderRole,
                      );
                    },
                  );
                },
              ),
            ),
            ChatComposer(onSend: _sendMessage),
          ],
        ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({required this.viewerRole});

  final ChatSenderRole viewerRole;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final bool isStaff = viewerRole == ChatSenderRole.staff;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                isStaff ? 'No messages yet' : 'Start a conversation',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isStaff
                    ? 'This customer has not sent a message yet.'
                    : 'Ask us about medicines, prescriptions, quotes, payments or delivery.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
