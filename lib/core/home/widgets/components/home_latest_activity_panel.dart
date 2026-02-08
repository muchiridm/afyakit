import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/home/widgets/member/member_latest_activity_panel.dart';
import 'package:afyakit/core/home/widgets/staff/staff_latest_activity_panel.dart';
import 'package:flutter/material.dart';

class HomeLatestActivityPanel extends StatelessWidget {
  const HomeLatestActivityPanel({super.key, required this.entry});

  final EntryMode entry;

  bool get _isStaff => entry == EntryMode.staff;

  @override
  Widget build(BuildContext context) {
    // Staff → global activity
    // Member + Guest → personal activity
    return _isStaff
        ? const StaffLatestActivityPanel()
        : const MemberLatestActivityPanel();
  }
}
