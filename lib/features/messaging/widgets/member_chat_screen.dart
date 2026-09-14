// lib/features/messaging/widgets/member_chat_screen.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

import 'member_chat_conversations_screen.dart';

/// Backwards-compatible entry point.
///
/// Members now land on their conversations list instead of opening
/// a single permanent chat thread.
class MemberChatScreen extends StatelessWidget {
  const MemberChatScreen({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return MemberChatConversationsScreen(user: user);
  }
}
