// lib/features/messaging/widgets/staff_chat_inbox_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/utils/app_error_message.dart';
import 'package:afyakit/shared/widgets/app_error_pane.dart';

import '../models/chat_conversation.dart';
import '../providers/messaging_providers.dart';
import 'chat_conversation_screen.dart';

class StaffChatInboxScreen extends ConsumerWidget {
  const StaffChatInboxScreen({super.key, required this.user});

  static const double _inboxMaxWidth = 820;

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ChatConversation>> conversationsAsync = ref.watch(
      staffChatConversationsProvider,
    );

    return AppPage(
      title: 'Conversations',
      showBack: true,
      scrollable: false,
      maxWidth: _inboxMaxWidth,
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: AppErrorPane(
            title: 'Messages unavailable',
            message: appErrorMessage(
              error,
              fallback: 'We could not load customer conversations.',
            ),
          ),
        ),
        data: (conversations) {
          if (conversations.isEmpty) {
            return const _EmptyStaffInbox();
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final ChatConversation conversation = conversations[index];

              return _ConversationTile(
                conversation: conversation,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ChatConversationScreen(
                        conversationId: conversation.id,
                        user: user,
                        title: conversation.member.name.trim().isEmpty
                            ? 'Customer Chat'
                            : conversation.member.name,
                        senderRole: ChatSenderRole.staff,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final ChatConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final String name = conversation.member.name.trim().isEmpty
        ? 'Customer'
        : conversation.member.name.trim();

    final String preview =
        conversation.lastMessage?.text.trim().isNotEmpty == true
        ? conversation.lastMessage!.text.trim()
        : 'No messages yet';

    final String subtitle = _identityLabel(conversation);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(child: Text(_initials(name), maxLines: 1)),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: conversation.hasStaffUnread
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTime(conversation.updatedAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: conversation.hasStaffUnread
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      trailing: conversation.hasStaffUnread
          ? Badge(
              label: Text(
                conversation.staffUnreadCount > 99
                    ? '99+'
                    : conversation.staffUnreadCount.toString(),
              ),
            )
          : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  String _identityLabel(ChatConversation conversation) {
    final List<String> parts = <String>[
      if ((conversation.member.accountNumber ?? '').trim().isNotEmpty)
        conversation.member.accountNumber!.trim(),
      if ((conversation.member.phoneNumber ?? '').trim().isNotEmpty)
        conversation.member.phoneNumber!.trim(),
    ];

    return parts.join(' · ');
  }

  String _initials(String name) {
    final List<String> words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);

    if (words.isEmpty) {
      return '?';
    }

    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }

    return '${words.first.substring(0, 1)}'
            '${words.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _formatTime(DateTime? value) {
    if (value == null) {
      return '';
    }

    final DateTime local = value.toLocal();
    final DateTime now = DateTime.now();

    final bool sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;

    if (sameDay) {
      return DateFormat('HH:mm').format(local);
    }

    return DateFormat('dd MMM').format(local);
  }
}

class _EmptyStaffInbox extends StatelessWidget {
  const _EmptyStaffInbox();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              'No customer conversations',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New member conversations will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
