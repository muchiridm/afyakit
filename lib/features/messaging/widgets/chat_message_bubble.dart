// lib/features/messaging/widgets/chat_message_bubble.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/chat_conversation.dart';
import '../models/chat_message.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.viewerRole,
  });

  final ChatMessage message;
  final ChatSenderRole viewerRole;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final bool isMine = message.sender.role == viewerRole;
    final bool isStaffMessage = message.sender.role == ChatSenderRole.staff;

    final Alignment alignment = isMine
        ? Alignment.centerRight
        : Alignment.centerLeft;

    final Color backgroundColor;

    if (isStaffMessage) {
      backgroundColor = isMine
          ? theme.colorScheme.primary
          : theme.colorScheme.primaryContainer;
    } else {
      backgroundColor = isMine
          ? theme.colorScheme.secondaryContainer
          : theme.colorScheme.surfaceContainerHighest;
    }

    final Color foregroundColor;

    if (isStaffMessage && isMine) {
      foregroundColor = theme.colorScheme.onPrimary;
    } else if (isStaffMessage) {
      foregroundColor = theme.colorScheme.onPrimaryContainer;
    } else if (isMine) {
      foregroundColor = theme.colorScheme.onSecondaryContainer;
    } else {
      foregroundColor = theme.colorScheme.onSurfaceVariant;
    }

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: EdgeInsets.only(
            left: isMine ? 64 : 12,
            right: isMine ? 12 : 64,
            top: 4,
            bottom: 4,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMine ? 18 : 5),
                bottomRight: Radius.circular(isMine ? 5 : 18),
              ),
              border: isMine
                  ? null
                  : Border.all(color: theme.dividerColor.withOpacity(0.25)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isStaffMessage
                            ? Icons.local_pharmacy_outlined
                            : Icons.person_outline_rounded,
                        size: 14,
                        color: foregroundColor.withOpacity(0.78),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          isMine ? 'You' : _senderLabel(message),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: foregroundColor.withOpacity(0.82),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  SelectableText(
                    message.text,
                    textAlign: isMine ? TextAlign.right : TextAlign.left,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foregroundColor,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatTime(message.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: foregroundColor.withOpacity(0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _senderLabel(ChatMessage message) {
    final String name = message.sender.name.trim();

    if (message.sender.role == ChatSenderRole.staff) {
      return name.isEmpty ? 'DawaPap' : name;
    }

    return name.isEmpty ? 'Member' : name;
  }

  String _formatTime(DateTime? value) {
    if (value == null) {
      return 'Sending…';
    }

    return DateFormat('HH:mm').format(value.toLocal());
  }
}
