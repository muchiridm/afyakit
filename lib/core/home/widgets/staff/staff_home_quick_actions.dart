// lib/core/home/widgets/staff/staff_home_quick_actions.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/home/widgets/shared/home_dashboard/home_quick_action_button.dart';

import 'package:afyakit/features/clinical/profiles/widgets/profiles_screen.dart';
import 'package:afyakit/features/clinical/prescriptions/widgets/prescriptions_screen.dart';
import 'package:afyakit/features/messaging/providers/messaging_providers.dart';
import 'package:afyakit/features/retail/contacts/widgets/contacts_screen.dart';

class StaffHomeQuickActions extends ConsumerWidget {
  const StaffHomeQuickActions({super.key, this.onChat});

  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VoidCallback? chatAction = onChat;

    final int chatUnreadCount = chatAction == null
        ? 0
        : ref.watch(staffUnreadMessagesProvider);

    return HomeQuickActionButton(
      actions: [
        HomeQuickAction(
          label: 'Add contact / customer',
          icon: Icons.person_add_outlined,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ContactsScreen()),
            );
          },
        ),
        HomeQuickAction(
          label: 'Add profile',
          icon: Icons.person_add_alt_1_outlined,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const ProfilesScreen(allowExplicitContactLink: true),
              ),
            );
          },
        ),
        HomeQuickAction(
          label: 'Upload prescription',
          icon: Icons.upload_file_outlined,
          onPressed: () {
            PrescriptionsScreen.open(
              context: context,
              forceProfilePickerMode: true,
            );
          },
        ),
        if (chatAction != null)
          HomeQuickAction(
            label: 'Chat',
            icon: Icons.chat_bubble_outline_rounded,
            badgeCount: chatUnreadCount,
            onPressed: chatAction,
          ),
      ],
    );
  }
}
