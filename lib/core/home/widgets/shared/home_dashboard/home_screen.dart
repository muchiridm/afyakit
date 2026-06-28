// lib/core/home/widgets/shared/home_dashboard/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';
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

  /// HomeShell should only build HomeScreen for authenticated users.
  ///
  /// Retail guests go directly to CatalogScreen.
  /// Non-retail guests go directly to LoginScreen.
  final AuthUser? user;

  double get _maxWidth {
    return switch (effectiveEntry) {
      EntryMode.staff => AppLayout.dashboardMaxWidth,
      EntryMode.member => AppLayout.dashboardMaxWidth,

      // Safety fallback only. HomeShell should not send guests here.
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
        EntryMode.member => HomeMemberBody(user: user),
        EntryMode.staff => HomeStaffBody(user: user),

        // Safety fallback only.
        // Guests should never reach this screen after the HomeShell update.
        EntryMode.guest => const _UnexpectedGuestHomeFallback(),
      },
    );
  }
}

class _UnexpectedGuestHomeFallback extends StatelessWidget {
  const _UnexpectedGuestHomeFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Guest home is unavailable. Please open the catalog.'),
    );
  }
}
