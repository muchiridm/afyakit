// lib/core/home/widgets/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/home/widgets/guest/home_guest_body.dart';
import 'package:afyakit/core/home/widgets/member/home_member_body.dart';
import 'package:afyakit/core/home/widgets/staff/home_staff_body.dart';
import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.realEntry,
    required this.effectiveEntry,
    required this.user,
  });

  final EntryMode realEntry;
  final EntryMode effectiveEntry;

  /// In HomeShell we only build HomeScreen for non-guests,
  /// but keep nullable for safety/future reuse.
  final AuthUser? user;

  double get _maxWidth {
    return switch (effectiveEntry) {
      EntryMode.staff => AppLayout.dashboardMaxWidth,
      EntryMode.member => AppLayout.dashboardMaxWidth,
      EntryMode.guest => AppLayout.contentMaxWidth,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPage(
      scrollable: true,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(0),
        child: SizedBox.shrink(),
      ),
      maxWidth: _maxWidth,
      padding: AppLayout.pagePadding,
      body: switch (effectiveEntry) {
        EntryMode.guest => const HomeGuestBody(),
        EntryMode.member => HomeMemberBody(user: user),
        EntryMode.staff => HomeStaffBody(user: user),
      },
    );
  }
}
