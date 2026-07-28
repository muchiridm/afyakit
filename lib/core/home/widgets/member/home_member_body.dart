// lib/core/home/widgets/member/home_member_body.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/activities/shared/member_activity_history_screen.dart';
import 'package:afyakit/core/home/activities/shared/member_latest_activity_panel.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/home/widgets/shared/home_dashboard/home_header.dart';
import 'package:afyakit/core/home/widgets/shared/home_dashboard/home_shared.dart';
import 'package:afyakit/core/home/widgets/member/member_features_panel.dart';

import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';

import 'package:afyakit/shared/theme/app_shape.dart';

class HomeMemberBody extends StatelessWidget {
  const HomeMemberBody({super.key, required this.user});

  final AuthUser? user;

  void _openCatalog(BuildContext context, {String? q, bool autofocus = true}) {
    final query = (q ?? '').trim();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogScreen(
          initialQuery: query.isEmpty ? null : query,
          autofocusSearch: autofocus,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = user;

    final greeting = currentUser?.computedDisplayName ?? 'Member';

    final memberId = (currentUser?.accountNumber ?? '').trim();
    final visibleMemberId = memberId.isEmpty ? null : memberId;

    return homeVerticalStack([
      // Original header remains full-width and unchanged.
      const HomeHeader(
        entry: EntryMode.member,
        showDeliveryBanner: false,
        showHomeButton: false,
      ),

      // Only the greeting and My account are responsive here.
      _MemberIntroSection(
        greeting: greeting,
        memberId: visibleMemberId,
        user: currentUser,
      ),

      _MemberMainSections(
        search: _MemberSearchColumn(
          onSearch: (query) => _openCatalog(context, q: query),
          onBrowseCatalog: () => _openCatalog(context, autofocus: true),
        ),
        activity: _MemberActivityColumn(
          user: currentUser,
          hasMemberId: memberId.isNotEmpty,
        ),
      ),

      const SizedBox(height: AppShape.gap12),
    ], gap: AppShape.gap14);
  }
}

class _MemberMainSections extends StatelessWidget {
  const _MemberMainSections({required this.search, required this.activity});

  static const double _twoColumnBreakpoint = 900;

  final Widget search;
  final Widget activity;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= _twoColumnBreakpoint;

        if (!useTwoColumns) {
          return homeVerticalStack([search, activity], gap: AppShape.gap12);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: search),
            const SizedBox(width: AppShape.gap14),
            Expanded(child: activity),
          ],
        );
      },
    );
  }
}

class _MemberIntroSection extends StatelessWidget {
  const _MemberIntroSection({
    required this.greeting,
    required this.memberId,
    required this.user,
  });

  static const double _twoColumnBreakpoint = 900;

  final String greeting;
  final String? memberId;
  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= _twoColumnBreakpoint;

        final greetingSection = Align(
          alignment: useTwoColumns ? Alignment.centerLeft : Alignment.center,
          child: _MemberGreetingSection(
            greeting: greeting,
            memberId: memberId,
            centered: !useTwoColumns,
          ),
        );

        final accountSection = HomeSection(
          title: 'My account',
          icon: Icons.account_circle_outlined,
          centerHeader: !useTwoColumns,
          child: MemberFeaturesPanel(user: user, centered: !useTwoColumns),
        );

        if (!useTwoColumns) {
          return homeVerticalStack([
            greetingSection,
            accountSection,
          ], gap: AppShape.gap14);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: greetingSection),
            const SizedBox(width: AppShape.gap14),
            Expanded(child: accountSection),
          ],
        );
      },
    );
  }
}

class _MemberGreetingSection extends StatelessWidget {
  const _MemberGreetingSection({
    required this.greeting,
    required this.memberId,
    required this.centered,
  });

  final String greeting;
  final String? memberId;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cleanMemberId = (memberId ?? '').trim();

    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          'Hi, $greeting 👋',
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (cleanMemberId.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Member ID: $cleanMemberId',
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ],
    );
  }
}

class _MemberSearchColumn extends StatelessWidget {
  const _MemberSearchColumn({
    required this.onSearch,
    required this.onBrowseCatalog,
  });

  final void Function(String query) onSearch;
  final VoidCallback onBrowseCatalog;

  @override
  Widget build(BuildContext context) {
    return HomeSection(
      title: 'Search',
      icon: Icons.search_rounded,
      child: HomeCatalogSearchHero(
        autofocus: false,
        hintText: 'Search medicines, brands or health products',
        footerText: 'Search the catalogue',
        onSearch: onSearch,
        onBrowse: onBrowseCatalog,
      ),
    );
  }
}

class _MemberActivityColumn extends StatelessWidget {
  const _MemberActivityColumn({required this.user, required this.hasMemberId});

  final AuthUser? user;
  final bool hasMemberId;

  @override
  Widget build(BuildContext context) {
    final currentUser = user;

    if (currentUser == null) {
      return const HomeMemberMissingUserHint();
    }

    if (!hasMemberId) {
      return const HomeMemberMissingAccountHint();
    }

    return QuietHomePanel(
      child: MemberLatestActivityPanel(
        contactId: currentUser.contactId,
        accountNumber: currentUser.accountNumber,
        onTitleTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MemberActivityHistoryScreen(
              contactId: currentUser.contactId,
              accountNumber: currentUser.accountNumber,
            ),
          ),
        ),
      ),
    );
  }
}

class HomeMemberMissingUserHint extends StatelessWidget {
  const HomeMemberMissingUserHint({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeInfoCard(
      icon: Icons.info_outline,
      title: 'Loading your account…',
      body:
          'Your member dashboard will appear once your profile is loaded. If it stays like this, refresh or log out and log in again.',
    );
  }
}

class HomeMemberMissingAccountHint extends StatelessWidget {
  const HomeMemberMissingAccountHint({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeInfoCard(
      icon: Icons.warning_amber_rounded,
      title: 'Member ID missing',
      body:
          'Your accountNumber is missing, so member activity can’t be loaded. This is usually a backend/profile issue. Fix: ensure your member profile has accountNumber.',
    );
  }
}
