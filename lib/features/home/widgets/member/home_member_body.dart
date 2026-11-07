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

    final pharmacyEnabled = ref.watch(appPharmacyEnabledProvider);
    final retailEnabled = ref.watch(appRetailEnabledProvider);

    // Catalogue search is available only for pharmacy-commerce apps.
    // Occuwell and Afya Tracker do not show catalogue search
    // unless both capabilities are explicitly enabled.
    final showCatalogSearch = pharmacyEnabled && retailEnabled;

    return homeVerticalStack([
      const HomeHeader(
        entry: EntryMode.member,
        showDeliveryBanner: false,
        showHomeButton: false,
      ),

      // Same responsive two-column structure as Staff:
      // Left: greeting and member features.
      // Right: optional catalogue search and latest activities.
      HomeDashboardTwoColumnLayout(
        leading: _MemberAccountColumn(
          user: currentUser,
          greeting: greeting,
          memberId: memberId.isEmpty ? null : memberId,
          sectionTitle: 'My Records',
        ),
        trailing: _MemberMainColumn(
          user: currentUser,
          hasMemberId: memberId.isNotEmpty,
          showCatalogSearch: showCatalogSearch,
          onSearch: (query) => _openCatalog(context, q: query),
          onBrowseCatalog: (query) =>
              _openCatalog(context, q: query, autofocus: query.trim().isEmpty),
        ),
      ),

      const SizedBox(height: AppShape.gap12),
    ], gap: AppShape.gap14);
  }
}

// ─────────────────────────────────────────
// Member account and records
// ─────────────────────────────────────────

class _MemberAccountColumn extends StatelessWidget {
  const _MemberAccountColumn({
    required this.user,
    required this.greeting,
    required this.memberId,
    required this.sectionTitle,
  });

  final AuthUser? user;
  final String greeting;
  final String? memberId;
  final String sectionTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppShape.gap14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: homeVerticalStack([
        _MemberGreetingSection(greeting: greeting, memberId: memberId),

        const Divider(height: AppShape.gap14),

        Row(
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 22,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppShape.gap10),
            Expanded(
              child: Text(
                sectionTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        MemberFeaturesPanel(user: user, centered: false),
      ], gap: AppShape.gap14),
    );
  }
}

// ─────────────────────────────────────────
// Member greeting
// ─────────────────────────────────────────

class _MemberGreetingSection extends StatelessWidget {
  const _MemberGreetingSection({
    required this.greeting,
    required this.memberId,
  });

  final String greeting;
  final String? memberId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cleanMemberId = (memberId ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi, $greeting 👋',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),

        if (cleanMemberId.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Member ID: $cleanMemberId',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────
// Right column: Search and activities
// ─────────────────────────────────────────

class _MemberMainColumn extends StatelessWidget {
  const _MemberMainColumn({
    required this.user,
    required this.hasMemberId,
    required this.showCatalogSearch,
    required this.onSearch,
    required this.onBrowseCatalog,
  });

  final AuthUser? user;
  final bool hasMemberId;
  final bool showCatalogSearch;

  final void Function(String query) onSearch;
  final void Function(String query) onBrowseCatalog;

  @override
  Widget build(BuildContext context) {
    return homeVerticalStack([
      // No redundant "Search" heading.
      // The field already has a search icon and descriptive hint.
      if (showCatalogSearch)
        HomeCatalogSearchHero(
          autofocus: false,
          hintText: 'Search medicines, brands or health products',
          footerText: 'Search the catalogue',
          onSearch: onSearch,
          onBrowse: onBrowseCatalog,
        ),

      _MemberActivityColumn(user: user, hasMemberId: hasMemberId),
    ], gap: AppShape.gap14);
  }
}

// ─────────────────────────────────────────
// Latest activities
// ─────────────────────────────────────────

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
        contactId: currentUser.accountNumber,
        accountNumber: currentUser.accountNumber,
        onTitleTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MemberActivityHistoryScreen(
              contactId: currentUser.accountNumber,
              accountNumber: currentUser.accountNumber,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Missing member information
// ─────────────────────────────────────────

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
