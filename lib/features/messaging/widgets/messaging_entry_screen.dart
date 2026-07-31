// lib/features/messaging/widgets/messaging_entry_screen.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';

import 'member_chat_conversations_screen.dart';
import 'staff_chat_inbox_screen.dart';

class MessagingEntryScreen extends StatelessWidget {
  const MessagingEntryScreen({
    super.key,
    required this.entry,
    required this.user,
  });

  final EntryMode entry;
  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      EntryMode.member => MemberChatConversationsScreen(user: user),
      EntryMode.staff => StaffChatInboxScreen(user: user),
      EntryMode.guest => const _MessagingUnavailableScreen(),
    };
  }
}

class _MessagingUnavailableScreen extends StatelessWidget {
  const _MessagingUnavailableScreen();

  @override
  Widget build(BuildContext context) {
    return const AppPage(
      title: 'Chat',
      showBack: true,
      scrollable: false,
      maxWidth: AppLayout.contentMaxWidth,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Please log in or sign up to use in-app chat.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
