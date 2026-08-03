// lib/core/home/activities/shared/member_activity_history_screen.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/home/activities/shared/member_latest_activity_panel.dart';
import 'package:afyakit/shared/layout/app_header.dart';
import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';

class MemberActivityHistoryScreen extends StatelessWidget {
  const MemberActivityHistoryScreen({
    super.key,
    required this.contactId,
    this.accountNumber,
  });

  final String? contactId;
  final String? accountNumber;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      maxWidth: AppLayout.contentMaxWidth,
      header: const AppHeader(
        title: 'Activity History',
        variant: AppHeaderVariant.card,
      ),
      body: MemberLatestActivityPanel(
        contactId: contactId,
        accountNumber: accountNumber,
        title: 'All Activity',
        maxItems: null,
        emptyText: 'No activity history yet.',
      ),
    );
  }
}
