// lib/core/home/widgets/shared/home_dashboard/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';

import 'package:afyakit/core/home/widgets/member/home_member_body.dart';
import 'package:afyakit/core/home/widgets/member/member_home_quick_action.dart';

import 'package:afyakit/core/home/widgets/staff/home_staff_body.dart';
import 'package:afyakit/core/home/widgets/staff/staff_home_quick_actions.dart';

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
      key: ValueKey<String>('home-page-${effectiveEntry.name}'),
      scrollable: true,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(0),
        child: SizedBox.shrink(),
      ),
      maxWidth: _maxWidth,
      padding: AppLayout.pagePadding,
      fab: _buildQuickActions(context),
      fabAlignment: Alignment.bottomRight,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return switch (effectiveEntry) {
      EntryMode.member => HomeMemberBody(
        key: ValueKey<String>(
          'member-home-body-${user?.contactId ?? 'unknown'}',
        ),
        user: user,
      ),
      EntryMode.staff => HomeStaffBody(
        key: const ValueKey<String>('staff-home-body'),
        user: user,
      ),
      EntryMode.guest => const _UnexpectedGuestHomeFallback(
        key: ValueKey<String>('guest-home-fallback'),
      ),
    };
  }

  Widget? _buildQuickActions(BuildContext context) {
    return switch (effectiveEntry) {
      EntryMode.member => MemberHomeQuickActions(
        key: ValueKey<String>(
          'member-home-quick-actions-${user?.contactId ?? 'unknown'}',
        ),
        user: user,
        onChat: () => _openChat(context),
      ),
      EntryMode.staff => StaffHomeQuickActions(
        key: const ValueKey<String>('staff-home-quick-actions'),
        onChat: () => _openChat(context),
      ),
      EntryMode.guest => null,
    };
  }

  void _openChat(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat navigation is not connected yet.')),
    );
  }
}

class _UnexpectedGuestHomeFallback extends StatelessWidget {
  const _UnexpectedGuestHomeFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Guest home is unavailable. Please open the catalog.'),
    );
  }
}
