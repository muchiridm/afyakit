// lib/core/home/widgets/member/home_member_body.dart

import 'package:afyakit/features/clinical/patients/models/patient_profile_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/activities/shared/member_activity_history_screen.dart';
import 'package:afyakit/core/home/activities/shared/member_latest_activity_panel.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/home/widgets/shared/home_dashboard/home_header.dart';
import 'package:afyakit/core/home/widgets/shared/home_dashboard/home_shared.dart';
import 'package:afyakit/core/hq/tenants/models/feature_keys.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_profile_providers.dart';

import 'package:afyakit/features/clinical/patients/widgets/patient_profiles_screen.dart';
import 'package:afyakit/features/clinical/prescriptions/widgets/prescriptions_screen.dart';
import 'package:afyakit/features/delivery_addresses/providers/delivery_address_providers.dart';
import 'package:afyakit/features/delivery_addresses/widgets/delivery_addresses_screen.dart';
import 'package:afyakit/features/health_metrics/widgets/health_metrics_dashboard_screen.dart';
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
    final currentUser = user;

    final greeting = currentUser == null
        ? 'Member'
        : currentUser.computedDisplayName;

    final memberId = (currentUser?.accountNumber ?? '').trim();
    final visibleMemberId = memberId.isEmpty ? null : memberId;

    return homeVerticalStack([
      HomeHeader(
        entry: EntryMode.member,
        greetingName: greeting,
        memberId: visibleMemberId,
        showDeliveryBanner: false,
        showHomeButton: false,
      ),
      HomeDashboardTwoColumnLayout(
        leading: _MemberFeaturesColumn(user: currentUser),
        trailing: _MemberMainColumn(
          user: currentUser,
          hasMemberId: memberId.isNotEmpty,
          onSearch: (query) => _openCatalog(context, q: query),
          onBrowseCatalog: () => _openCatalog(context, autofocus: true),
        ),
      ),
      const SizedBox(height: AppShape.gap12),
    ], gap: AppShape.gap14);
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
          child: MemberLatestActivityPanel(
            contactId: user!.contactId,
            accountNumber: user!.accountNumber,
            onTitleTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MemberActivityHistoryScreen(
                  contactId: user!.contactId,
                  accountNumber: user!.accountNumber,
                ),
              ),
            ),
          ),
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
        icon: Icons.monitor_heart_outlined,
        title: 'Follow your health over time',
        body:
            'Record health measurements for yourself and your dependents, then review changes and trends over time.',
      ),
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

class HomeMemberQuickActions extends ConsumerWidget {
  const HomeMemberQuickActions({super.key, required this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactId = user?.contactId;

    final tenantProfile = ref.watch(tenantProfileProvider).valueOrNull;

    final healthMetricsEnabled =
        tenantProfile?.has(FeatureKeys.healthMetrics) == true;

    return Wrap(
      spacing: AppShape.gap10,
      runSpacing: AppShape.gap10,
      children: [
        if (healthMetricsEnabled)
          HomeActionChip(
            icon: Icons.monitor_heart_outlined,
            label: 'My Health Metrics',
            onTap: () => _openHealthMetrics(context, contactId: contactId),
          ),
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
          onTap: () {
            final scope = ref.read(currentUserDeliveryAddressScopeProvider);

            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DeliveryAddressesScreen(scope: scope),
              ),
            );
          },
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

  Future<void> _openHealthMetrics(
    BuildContext context, {
    required String? contactId,
  }) async {
    final normalizedContactId = contactId?.trim();

    if (normalizedContactId == null || normalizedContactId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account is not linked to a contact.'),
        ),
      );

      return;
    }

    final patient = await Navigator.of(context).push<PatientProfile>(
      MaterialPageRoute<PatientProfile>(
        builder: (_) => PatientProfilesScreen(
          contactId: normalizedContactId,
          allowExplicitContactLink: false,
          selectionMode: true,
          selectionTitle: 'Select health profile',
        ),
      ),
    );

    if (patient == null || !context.mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HealthMetricsDashboardScreen(initialPatient: patient),
      ),
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
          'Save patient profiles for yourself, children, spouse, parents, and other dependents. Health measurements and prescriptions remain linked to the correct profile.',
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
