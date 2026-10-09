// lib/features/home/widgets/member/home_member_body.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/providers/app_feature_providers.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

import 'package:afyakit/features/home/activities/shared/member_activity_history_screen.dart';
import 'package:afyakit/features/home/activities/shared/member_latest_activity_panel.dart';
import 'package:afyakit/features/home/enums/entry_mode.dart';
import 'package:afyakit/features/home/widgets/member/member_features_panel.dart';
import 'package:afyakit/features/home/widgets/shared/home_dashboard/home_header.dart';
import 'package:afyakit/features/home/widgets/shared/home_dashboard/home_shared.dart';

import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';

import 'package:afyakit/shared/theme/app_shape.dart';

class HomeMemberBody extends ConsumerWidget {
  const HomeMemberBody({super.key, required this.user});

  final AuthUser? user;

  void _openCatalog(BuildContext context, {String? q, bool autofocus = true}) {
    final query = (q ?? '').trim();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogScreen(
          initialQuery: query.isEmpty ? null : query,
          autofocusSearch: autofocus,
          entry: EntryMode.member,
          user: user,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = user;

    final greeting = currentUser?.computedDisplayName ?? 'Member';

    final memberId = (currentUser?.accountNumber ?? '').trim();

    final clinicalEnabled = ref.watch(appClinicalEnabledProvider);

    final occupationalHealthEnabled = ref.watch(
      appOccupationalHealthEnabledProvider,
    );

    final pharmacyEnabled = ref.watch(appPharmacyEnabledProvider);

    final retailEnabled = ref.watch(appRetailEnabledProvider);

    /*
     * Catalogue search is deliberately a pharmacy-commerce
     * experience.
     *
     * AfyaTracker:
     *   health_tracking = true
     *   pharmacy = false
     *   retail = false
     *   → no catalogue search
     *
     * Occuwell:
     *   occupational_health = true
     *   pharmacy = false
     *   retail = false
     *   → no catalogue search
     *
     * DawaPap:
     *   pharmacy = true
     *   retail = true
     *   → catalogue search
     */
    final showCatalogSearch = pharmacyEnabled && retailEnabled;

    /*
     * A health-tracking application should present the
     * member shortcuts as "My health" rather than the more
     * generic commerce-oriented "My account".
     */
    final healthFocused = clinicalEnabled || occupationalHealthEnabled;

    final accountSectionTitle = healthFocused && !showCatalogSearch
        ? 'My health'
        : 'My account';

    final activity = _MemberActivityColumn(
      user: currentUser,
      hasMemberId: memberId.isNotEmpty,
    );

    return homeVerticalStack([
      const HomeHeader(
        entry: EntryMode.member,
        showDeliveryBanner: false,
        showHomeButton: false,
      ),

      _MemberIntroSection(
        greeting: greeting,
        memberId: memberId.isEmpty ? null : memberId,
        user: currentUser,
        sectionTitle: accountSectionTitle,
      ),

      _MemberMainSections(
        primary: showCatalogSearch
            ? _MemberSearchColumn(
                onSearch: (query) => _openCatalog(context, q: query),
                onBrowseCatalog: (query) => _openCatalog(
                  context,
                  q: query,
                  autofocus: query.trim().isEmpty,
                ),
              )
            : null,
        activity: activity,
      ),

      const SizedBox(height: AppShape.gap12),
    ], gap: AppShape.gap14);
  }
}

class _MemberMainSections extends StatelessWidget {
  const _MemberMainSections({required this.primary, required this.activity});

  final Widget? primary;
  final Widget activity;

  @override
  Widget build(BuildContext context) {
    final primarySection = primary;

    /*
     * Health-first applications such as AfyaTracker and
     * Occuwell do not need an artificial empty left column.
     * Recent activity simply uses the available width.
     */
    if (primarySection == null) {
      return activity;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return homeVerticalStack([
            primarySection,
            activity,
          ], gap: AppShape.gap12);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: primarySection),
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
    required this.sectionTitle,
  });

  final String greeting;
  final String? memberId;
  final AuthUser? user;
  final String sectionTitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 900;

        final greetingSection = Align(
          alignment: twoColumns ? Alignment.centerLeft : Alignment.center,
          child: _MemberGreetingSection(
            greeting: greeting,
            memberId: memberId,
            centered: !twoColumns,
          ),
        );

        final accountSection = HomeSection(
          title: sectionTitle,
          icon: Icons.account_circle_outlined,
          centerHeader: false,
          child: MemberFeaturesPanel(user: user, centered: !twoColumns),
        );

        if (!twoColumns) {
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
  final void Function(String query) onBrowseCatalog;

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
          'Your member dashboard will appear once your profile is loaded. '
          'If it stays like this, refresh or log out and log in again.',
    );
  }
}

class HomeMemberMissingAccountHint extends StatelessWidget {
  const HomeMemberMissingAccountHint({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeInfoCard(
      icon: Icons.info_outline,
      title: 'Activity unavailable',
      body:
          'We could not load your member number. '
          'Refresh the page to try again. '
          'If the problem continues, contact support for help with your account.',
    );
  }
}
