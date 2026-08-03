// lib/core/home/activities/shared/staff_activity_history_screen.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/home/activities/shared/staff_latest_activity_panel.dart';
import 'package:afyakit/shared/layout/app_header.dart';
import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';

class StaffActivityHistoryScreen extends StatelessWidget {
  const StaffActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPage(
      maxWidth: AppLayout.dashboardMaxWidth,
      header: AppHeader(
        title: 'Activity History',
        variant: AppHeaderVariant.card,
      ),
      body: StaffLatestActivityPanel(
        title: 'All Activity',
        maxItems: null,
        emptyText: 'No activity history yet.',
      ),
    );
  }
}
