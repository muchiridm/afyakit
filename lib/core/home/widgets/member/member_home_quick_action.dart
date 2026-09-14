// lib/core/home/widgets/member/member_home_quick_actions.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/widgets/shared/home_dashboard/home_quick_action_button.dart';

import 'package:afyakit/features/clinical/profiles/widgets/profile_picker.dart';
import 'package:afyakit/features/clinical/profiles/widgets/profiles_screen.dart';
import 'package:afyakit/features/clinical/prescriptions/widgets/prescriptions_screen.dart';
import 'package:afyakit/features/health_metrics/widgets/health_metrics_dashboard_screen.dart';
import 'package:afyakit/features/messaging/providers/messaging_providers.dart';

class MemberHomeQuickActions extends ConsumerWidget {
  const MemberHomeQuickActions({super.key, required this.user, this.onChat});

  final AuthUser? user;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? contactId = user?.contactId;
    final String memberUid = user?.uid.trim() ?? '';
    final VoidCallback? chatAction = onChat;

    final int chatUnreadCount = chatAction != null && memberUid.isNotEmpty
        ? ref.watch(memberUnreadMessagesProvider(memberUid))
        : 0;

    return HomeQuickActionButton(
      actions: [
        HomeQuickAction(
          label: 'Add profile',
          icon: Icons.person_add_alt_1_outlined,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProfilesScreen(
                  contactId: contactId,
                  allowExplicitContactLink: false,
                ),
              ),
            );
          },
        ),
        HomeQuickAction(
          label: 'Upload prescription',
          icon: Icons.upload_file_outlined,
          onPressed: () {
            PrescriptionsScreen.open(context: context, contactId: contactId);
          },
        ),
        HomeQuickAction(
          label: 'Health Metrics',
          icon: Icons.monitor_heart_outlined,
          onPressed: () => _openHealthMetrics(context, contactId: contactId),
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

  Future<void> _openHealthMetrics(
    BuildContext context, {
    required String? contactId,
  }) async {
    final String normalizedContactId = (contactId ?? '').trim();

    if (normalizedContactId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account is not linked to a customer profile.'),
        ),
      );

      return;
    }

    final patient = await showProfilePickerScreen(
      context: context,
      contactId: normalizedContactId,
      forcePickerMode: false,
    );

    if (patient == null || !context.mounted) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HealthMetricsDashboardScreen(
          initialPatient: patient,
          profilePickerContactId: normalizedContactId,
          memberMode: true,
        ),
      ),
    );
  }
}
