import 'package:afyakit/features/delivery_addresses/widgets/delivery_addresses_screen.dart';
import 'package:afyakit/features/patients/widgets/patient_profiles_screen.dart';
import 'package:flutter/material.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/home/widgets/components/home_header.dart';
import 'package:afyakit/core/home/widgets/home_shared.dart';
import 'package:afyakit/core/home/widgets/member/member_latest_activity_panel.dart';
import 'package:afyakit/core/home/widgets/staff/staff_features_panel.dart';
import 'package:afyakit/core/home/widgets/staff/staff_latest_activity_panel.dart';

import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';
import 'package:afyakit/features/retail/invoices/widgets/invoices_list_screen.dart';
import 'package:afyakit/features/retail/payments/zoho/widgets/payments_list_screen.dart';
import 'package:afyakit/features/retail/quotes/widgets/quotes_list_screen.dart';
import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';

import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/theme/app_shape.dart';

// ─────────────────────────────────────────────
// MEMBER HOME
// ─────────────────────────────────────────────
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
    final showMemberId = memberId.isNotEmpty ? memberId : null;

    return homeVerticalStack([
      HomeHeader(
        entry: EntryMode.member,
        greetingName: greeting,
        memberId: showMemberId,
        showDeliveryBanner: false,
        panelWidth: AppLayout.pageMaxW,
      ),
      HomeCatalogSearchHero(
        autofocus: false,
        footerText: 'Search the catalog or browse all items',
        onSearch: (q) => _openCatalog(context, q: q),
        onBrowse: () => _openCatalog(context, autofocus: true),
      ),
      const HomeMemberQuickActions(),
      const HomeMemberHouseholdInfoCard(),
      if (u == null)
        const HomeMemberMissingUserHint()
      else if (memberId.isEmpty)
        const HomeMemberMissingAccountHint()
      else
        const MemberLatestActivityPanel(),
      const SizedBox(height: AppShape.gap12),
    ]);
  }
}

class HomeMemberQuickActions extends StatelessWidget {
  const HomeMemberQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppShape.gap10,
      runSpacing: AppShape.gap10,
      children: [
        HomeActionChip(
          icon: Icons.grid_view_rounded,
          label: 'Browse catalog',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CatalogScreen())),
        ),
        HomeActionChip(
          icon: Icons.people_alt_outlined,
          label: 'My Profiles',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PatientProfilesScreen()),
          ),
        ),
        HomeActionChip(
          icon: Icons.location_on_outlined,
          label: 'Delivery Addresses',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DeliveryAddressesScreen()),
          ),
        ),
        HomeActionChip(
          icon: Icons.receipt_long_outlined,
          label: 'My Quotes',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const QuotesListScreen(scope: RetailDocScope.mine),
            ),
          ),
        ),
        HomeActionChip(
          icon: Icons.receipt_outlined,
          label: 'My Invoices',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const InvoicesListScreen(scope: RetailDocScope.mine),
            ),
          ),
        ),
        HomeActionChip(
          icon: Icons.payments_outlined,
          label: 'My Payments',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const PaymentsListScreen(scope: RetailDocScope.mine),
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
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.family_restroom_outlined, size: 20),
            const SizedBox(width: AppShape.gap10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage yourself and your dependents',
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You can save patient profiles for yourself, children, spouse, parents, and other dependents, plus multiple delivery addresses for prescriptions and orders.',
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
          ],
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
          'Your accountNumber is missing, so member activity can’t be loaded. This is usually a backend/profile issue. Fix: ensure your member profile has accountNumber (for example DP-000123).',
    );
  }
}

// ─────────────────────────────────────────────
// STAFF HOME
// ─────────────────────────────────────────────
class HomeStaffBody extends StatelessWidget {
  const HomeStaffBody({super.key, required this.user});

  final AuthUser? user;

  static const double _twoColBreakpoint = 720;

  @override
  Widget build(BuildContext context) {
    final greeting = user?.computedDisplayName ?? 'Staff';

    return homeVerticalStack([
      HomeHeader(
        entry: EntryMode.staff,
        greetingName: greeting,
        memberId: null,
        showDeliveryBanner: true,
        panelWidth: AppLayout.pageMaxW,
      ),
      LayoutBuilder(
        builder: (context, c) {
          final twoCol = c.maxWidth >= _twoColBreakpoint;

          const latest = StaffLatestActivityPanel();
          const features = StaffFeaturesPanel();

          if (!twoCol) {
            return homeVerticalStack([latest, features], gap: AppShape.gap12);
          }

          return const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: features),
              SizedBox(width: AppShape.gap12),
              Expanded(child: latest),
            ],
          );
        },
      ),
      const SizedBox(height: AppShape.gap12),
    ], gap: AppShape.gap16);
  }
}

// ─────────────────────────────────────────────
// GUEST HOME
// ─────────────────────────────────────────────
class HomeGuestBody extends StatelessWidget {
  const HomeGuestBody({super.key});

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
    return homeVerticalStack([
      HomeHeader(
        entry: EntryMode.guest,
        greetingName: 'Guest',
        memberId: null,
        showDeliveryBanner: false,
        panelWidth: AppLayout.pageMaxW,
      ),
      HomeCatalogSearchHero(
        autofocus: true,
        footerText: 'Browse without logging in',
        onSearch: (q) => _openCatalog(context, q: q),
        onBrowse: () => _openCatalog(context, autofocus: true),
        onSecondaryTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat with pharmacist (TODO)')),
          );
        },
        secondaryLabel: 'Chat pharmacist',
        secondaryIcon: Icons.chat_bubble_outline_rounded,
      ),
      const SizedBox(height: AppShape.gap12),
    ]);
  }
}
