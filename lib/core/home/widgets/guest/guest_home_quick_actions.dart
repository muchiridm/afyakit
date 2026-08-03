// lib/core/home/widgets/guest/guest_home_quick_actions.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/home/widgets/shared/home_dashboard/home_quick_action_button.dart';

class GuestHomeQuickActions extends StatelessWidget {
  const GuestHomeQuickActions({
    super.key,
    required this.onAuth,
    required this.onChat,
  });

  final VoidCallback onAuth;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return HomeQuickActionButton(
      actions: [
        HomeQuickAction(
          label: 'Log in / Sign up',
          icon: Icons.login_rounded,
          onPressed: onAuth,
        ),
        HomeQuickAction(
          label: 'Chat',
          icon: Icons.chat_bubble_outline_rounded,
          onPressed: onChat,
        ),
      ],
    );
  }
}
