// lib/core/home/activities/shared/staff_activity_history_screen.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/home/activities/shared/staff_latest_activity_panel.dart';
import 'package:afyakit/shared/theme/app_shape.dart';

class StaffActivityHistoryScreen extends StatelessWidget {
  const StaffActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity History')),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppShape.gap16),
          child: StaffLatestActivityPanel(
            title: 'Activity History',
            maxItems: null,
            emptyText: 'No activity history yet.',
          ),
        ),
      ),
    );
  }
}
