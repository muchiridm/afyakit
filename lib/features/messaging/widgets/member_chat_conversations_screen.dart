// lib/features/messaging/widgets/member_chat_conversations_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/utils/app_error_message.dart';
import 'package:afyakit/shared/widgets/app_error_pane.dart';

import '../models/chat_conversation.dart';
import '../providers/messaging_providers.dart';
import 'chat_conversation_screen.dart';

class MemberChatConversationsScreen extends ConsumerWidget {
  const MemberChatConversationsScreen({super.key, required this.user});

  static const double _maxWidth = 820;

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ChatConversation>> conversationsAsync = ref.watch(
      memberChatConversationsProvider(user.uid),
    );

    return AppPage(
      title: 'Conversations',
      showBack: true,
      scrollable: false,
      maxWidth: _maxWidth,
      fab: FloatingActionButton.extended(
        tooltip: 'Start a new conversation',
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New conversation'),
        onPressed: () => _startConversation(context, ref),
      ),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: AppErrorPane(
            title: 'Conversations unavailable',
            message: appErrorMessage(
              error,
              fallback: 'We could not load your conversations right now.',
            ),
          ),
        ),
        data: (conversations) {
          final List<ChatConversation> active = conversations
              .where((conversation) => !conversation.isClosed)
              .toList(growable: false);

          final List<ChatConversation> closed = conversations
              .where((conversation) => conversation.isClosed)
              .toList(growable: false);

          if (conversations.isEmpty) {
            return _EmptyConversations(
              onStart: () => _startConversation(context, ref),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 96),
            children: [
              if (active.isNotEmpty) ...[
                const _ConversationSectionHeader(
                  title: 'Active',
                  icon: Icons.forum_outlined,
                ),
                const SizedBox(height: 8),
                ...active.map(
                  (conversation) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MemberConversationTile(
                      conversation: conversation,
                      onTap: () => _openConversation(context, conversation),
                    ),
                  ),
                ),
              ],
              if (closed.isNotEmpty) ...[
                if (active.isNotEmpty) const SizedBox(height: 20),
                const _ConversationSectionHeader(
                  title: 'Closed',
                  icon: Icons.task_alt_outlined,
                ),
                const SizedBox(height: 8),
                ...closed.map(
                  (conversation) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MemberConversationTile(
                      conversation: conversation,
                      onTap: () => _openConversation(context, conversation),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _startConversation(BuildContext context, WidgetRef ref) async {
    final String? firstMessage = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _NewConversationSheet(),
    );

    if (firstMessage == null || !context.mounted) {
      return;
    }

    final String tenantId = ref.read(tenantIdProvider);
    final repository = ref.read(messagingRepositoryProvider);

    try {
      final String conversationId = await repository.createConversation(
        tenantId: tenantId,
        user: user,
        firstMessage: firstMessage,
      );

      if (!context.mounted) {
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChatConversationScreen(
            conversationId: conversationId,
            user: user,
            title: repository.composeConversationTitle(firstMessage),
            senderRole: ChatSenderRole.member,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              appErrorMessage(
                error,
                fallback: 'We could not start the conversation.',
              ),
            ),
          ),
        );
    }
  }

  void _openConversation(BuildContext context, ChatConversation conversation) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatConversationScreen(
          conversationId: conversation.id,
          user: user,
          title: conversation.title,
          senderRole: ChatSenderRole.member,
        ),
      ),
    );
  }
}

class _ConversationSectionHeader extends StatelessWidget {
  const _ConversationSectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 19, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MemberConversationTile extends StatelessWidget {
  const _MemberConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final ChatConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final String preview =
        conversation.lastMessage?.text.trim().isNotEmpty == true
        ? conversation.lastMessage!.text.trim()
        : 'No messages yet';

    final int unreadCount = conversation.memberUnreadCount;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: conversation.isClosed
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.primaryContainer,
          foregroundColor: conversation.isClosed
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onPrimaryContainer,
          child: Icon(
            conversation.isClosed
                ? Icons.task_alt_outlined
                : Icons.chat_bubble_outline_rounded,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: unreadCount > 0
                      ? FontWeight.w800
                      : FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _StatusChip(status: conversation.status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: unreadCount > 0
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _dateLabel(conversation),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        trailing: unreadCount > 0
            ? Badge(
                label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
              )
            : const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }

  String _dateLabel(ChatConversation conversation) {
    final DateTime? createdAt = conversation.createdAt;
    final DateTime? updatedAt = conversation.updatedAt;
    final DateTime? closedAt = conversation.closedAt;

    final List<String> parts = <String>[
      if (createdAt != null) 'Opened ${_formatDate(createdAt)}',
      if (conversation.isClosed && closedAt != null)
        'Closed ${_formatDate(closedAt)}'
      else if (updatedAt != null)
        'Updated ${_formatDateTime(updatedAt)}',
    ];

    return parts.join(' · ');
  }

  String _formatDate(DateTime value) {
    return DateFormat('dd MMM yyyy').format(value.toLocal());
  }

  String _formatDateTime(DateTime value) {
    final DateTime local = value.toLocal();
    final DateTime now = DateTime.now();

    final bool sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;

    if (sameDay) {
      return DateFormat('HH:mm').format(local);
    }

    return DateFormat('dd MMM yyyy').format(local);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ChatConversationStatus status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool closed = status == ChatConversationStatus.closed;

    final Color background = closed
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.primaryContainer;

    final Color foreground = closed
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            closed ? Icons.task_alt_outlined : Icons.forum_outlined,
            size: 13,
            color: foreground,
          ),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forum_outlined,
                size: 52,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'No conversations yet',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start a conversation and tell us how we can help.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Start conversation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewConversationSheet extends StatefulWidget {
  const _NewConversationSheet();

  @override
  State<_NewConversationSheet> createState() {
    return _NewConversationSheetState();
  }
}

class _NewConversationSheetState extends State<_NewConversationSheet> {
  final TextEditingController _messageController = TextEditingController();

  bool get _canSubmit {
    return _messageController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _submit() {
    final String message = _messageController.text.trim();

    if (message.isEmpty) {
      return;
    }

    Navigator.of(context).pop(message);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + keyboardInset),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'New conversation',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'How can we help?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _messageController,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 7,
                  maxLength: 4000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Describe what you need help with',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _canSubmit ? _submit : null,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Start conversation'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
