// lib/core/home/widgets/member/home_member_body.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/widgets/activities/member_latest_activity_panel.dart';
import 'package:afyakit/core/home/widgets/dashboard/home_shared.dart';

import 'package:afyakit/features/clinical/patients/widgets/patient_profiles_screen.dart';
import 'package:afyakit/features/clinical/prescriptions/widgets/prescriptions_screen.dart';
import 'package:afyakit/features/delivery_addresses/widgets/delivery_addresses_screen.dart';
import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';
import 'package:afyakit/features/retail/invoices/widgets/invoices_list_screen.dart';
import 'package:afyakit/features/retail/quotes/widgets/quotes_list_screen.dart';
import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';

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
    final u = user;

    final greeting = (u == null) ? 'Member' : u.computedDisplayName;
    final memberId = (u?.accountNumber ?? '').trim();
    final showMemberId = memberId.isEmpty ? null : memberId;

    return homeVerticalStack([
      HomeDashboardTopBar(
        title: 'DawaPap',
        fallbackTitle: 'DawaPap',
        trailing: _MemberHeaderMeta(
          greetingName: greeting,
          memberId: showMemberId,
          align: TextAlign.right,
        ),
      ),

      HomeDashboardTwoColumnLayout(
        leading: _MemberFeaturesColumn(user: u),
        trailing: _MemberMainColumn(
          user: u,
          hasMemberId: memberId.isNotEmpty,
          onSearch: (q) => _openCatalog(context, q: q),
          onBrowseCatalog: () => _openCatalog(context, autofocus: true),
        ),
      ),

      const SizedBox(height: AppShape.gap12),
    ], gap: AppShape.gap14);
  }
}

class _MemberHeaderMeta extends StatelessWidget {
  const _MemberHeaderMeta({
    required this.greetingName,
    required this.memberId,
    required this.align,
  });

  final String greetingName;
  final String? memberId;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final cleanName = greetingName.trim().isEmpty
        ? 'Member'
        : greetingName.trim();

    return Column(
      crossAxisAlignment: align == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Welcome, $cleanName',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (memberId != null) ...[
          const SizedBox(height: 2),
          Text(
            'Member ID: $memberId',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: align,
            style: t.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _MemberMainColumn extends StatelessWidget {
  const _MemberMainColumn({
    required this.user,
    required this.hasMemberId,
    required this.onSearch,
    required this.onBrowseCatalog,
  });

  final AuthUser? user;
  final bool hasMemberId;
  final void Function(String query) onSearch;
  final VoidCallback onBrowseCatalog;

  @override
  Widget build(BuildContext context) {
    return homeVerticalStack([
      HomeSection(
        title: 'Search',
        icon: Icons.search_rounded,
        child: HomeCatalogSearchHero(
          autofocus: false,
          hintText: 'Search medicines, brands, conditions…',
          footerText: 'Search the catalog when you need medicine',
          onSearch: onSearch,
          onBrowse: onBrowseCatalog,
        ),
      ),

      if (user == null)
        const HomeMemberMissingUserHint()
      else if (!hasMemberId)
        const HomeMemberMissingAccountHint()
      else
        QuietHomePanel(
          child: MemberLatestActivityPanel(contactId: user!.contactId),
        ),
    ], gap: AppShape.gap14);
  }
}

class _MemberFeaturesColumn extends StatelessWidget {
  const _MemberFeaturesColumn({required this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    return homeVerticalStack([
      HomeSection(
        title: 'My account',
        icon: Icons.account_circle_outlined,
        child: HomeMemberQuickActions(user: user),
      ),
      const HomeMemberHouseholdInfoCard(),
      const HomeInfoCard(
        icon: Icons.receipt_long_outlined,
        title: 'Track your orders and payments',
        body:
            'View your quotes, invoices, and payments from one place. This keeps your medicine requests and billing history easy to follow.',
      ),
      const HomeInfoCard(
        icon: Icons.location_on_outlined,
        title: 'Save delivery locations',
        body:
            'Keep your home, office, or family delivery addresses ready so checkout is faster next time.',
      ),
    ], gap: AppShape.gap14);
  }
}

class HomeMemberQuickActions extends StatelessWidget {
  const HomeMemberQuickActions({super.key, required this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final contactId = user?.contactId;

    return Wrap(
      spacing: AppShape.gap10,
      runSpacing: AppShape.gap10,
      children: [
        HomeActionChip(
          icon: Icons.people_alt_outlined,
          label: 'My Profiles',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PatientProfilesScreen(
                contactId: contactId,
                allowExplicitContactLink: false,
              ),
            ),
          ),
        ),
        HomeActionChip(
          icon: Icons.description_outlined,
          label: 'My Prescriptions',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PrescriptionsScreen(contactId: contactId),
            ),
          ),
        ),
        HomeActionChip(
          icon: Icons.location_on_outlined,
          label: 'Delivery Addresses',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const DeliveryAddressesScreen(),
            ),
          ),
        ),
        HomeActionChip(
          icon: Icons.receipt_long_outlined,
          label: 'My Quotes',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const QuotesListScreen(scope: RetailDocScope.mine),
            ),
          ),
        ),
        HomeActionChip(
          icon: Icons.receipt_outlined,
          label: 'My Invoices',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const InvoicesListScreen(scope: RetailDocScope.mine),
            ),
          ),
        ),
      ],
    );
  }
}

class HomeMemberHouseholdInfoCard extends StatelessWidget {
  const HomeMemberHouseholdInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeInfoCard(
      icon: Icons.family_restroom_outlined,
      title: 'Manage yourself and your dependents',
      body:
          'Save patient profiles for yourself, children, spouse, parents, and other dependents. You can also keep multiple delivery addresses for prescriptions and orders.',
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
