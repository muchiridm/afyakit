// lib/shared/home/widgets/common/home_latest_activity_panel.dart

import 'package:afyakit/shared/home/models/home_mode.dart';
import 'package:afyakit/shared/home/widgets/member/member_latest_activity_panel.dart';
import 'package:afyakit/shared/home/widgets/staff/staff_latest_activity_panel.dart';
import 'package:flutter/material.dart';

class HomeLatestActivityPanel extends StatelessWidget {
  const HomeLatestActivityPanel({super.key, required this.mode});

  final HomeMode mode;

  @override
  Widget build(BuildContext context) {
    return switch (mode) {
      HomeMode.staff => const StaffLatestActivityPanel(),
      HomeMode.member => const MemberLatestActivityPanel(),
    };
  }
}
