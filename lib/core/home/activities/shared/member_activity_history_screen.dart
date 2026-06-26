// lib/core/home/activities/shared/member_activity_history_screen.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/home/activities/shared/member_latest_activity_panel.dart';
import 'package:afyakit/shared/theme/app_shape.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Activity History')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppShape.gap16),
          child: MemberLatestActivityPanel(
            contactId: contactId,
            accountNumber: accountNumber,
            title: 'Activity History',
            maxItems: null,
            emptyText: 'No activity history yet.',
          ),
        ),
      ),
    );
  }
}
