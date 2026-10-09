import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/providers/app_feature_providers.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

import 'package:afyakit/features/clinical/prescriptions/widgets/prescriptions_screen.dart';

import 'package:afyakit/features/delivery_addresses/providers/delivery_address_providers.dart';
import 'package:afyakit/features/delivery_addresses/widgets/delivery_addresses_screen.dart';

import 'package:afyakit/features/home/widgets/shared/home_dashboard/home_shared.dart';

import 'package:afyakit/features/records/health_metrics/widgets/health_metrics_dashboard_screen.dart';
import 'package:afyakit/features/records/profiles/models/profile_models.dart';
import 'package:afyakit/features/records/profiles/widgets/profiles_screen.dart';

import 'package:afyakit/features/retail/invoices/widgets/invoices_list_screen.dart';
import 'package:afyakit/features/retail/quotes/widgets/quotes_list_screen.dart';
import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';

import 'package:afyakit/shared/theme/app_shape.dart';

class MemberFeaturesPanel extends ConsumerWidget {
  const MemberFeaturesPanel({
    super.key,
    required this.user,
    this.centered = false,
  });

  static const double _gridBreakpoint = 600;

  final AuthUser? user;
  final bool centered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactId = user?.contactId;

    final clinicalEnabled = ref.watch(appClinicalEnabledProvider);
    final pharmacyEnabled = ref.watch(appPharmacyEnabledProvider);
    final retailEnabled = ref.watch(appRetailEnabledProvider);

    final actions = <Widget>[
      // ─────────────────────────────────────
      // Core Records
      //
      // Shared across all applications.
      // Record-level access is enforced
      // by the backend.
      // ─────────────────────────────────────
      HomeActionChip(
        icon: Icons.people_alt_outlined,
        label: 'My Profiles',
        onTap: () => _open(
          context,
          ProfilesScreen(contactId: contactId, allowExplicitContactLink: false),
        ),
      ),

      HomeActionChip(
        icon: Icons.monitor_heart_outlined,
        label: 'My Health Metrics',
        onTap: () => _openHealthMetrics(context, contactId: contactId),
      ),

      // ─────────────────────────────────────
      // Clinical
      //
      // Pharmacy does not require Clinical.
      // This entry is for clinical records,
      // not pharmacy dispensing snapshots.
      // ─────────────────────────────────────
      if (clinicalEnabled)
        HomeActionChip(
          icon: Icons.description_outlined,
          label: 'My Prescriptions',
          onTap: () =>
              PrescriptionsScreen.open(context: context, contactId: contactId),
        ),

      // ─────────────────────────────────────
      // Pharmacy
      // ─────────────────────────────────────
      if (pharmacyEnabled)
        HomeActionChip(
          icon: Icons.location_on_outlined,
          label: 'Delivery Addresses',
          onTap: () {
            final scope = ref.read(currentUserDeliveryAddressScopeProvider);

            _open(
              context,
              DeliveryAddressesScreen(scope: scope, memberMode: true),
            );
          },
        ),

      // ─────────────────────────────────────
      // Retail
      // ─────────────────────────────────────
      if (retailEnabled) ...[
        HomeActionChip(
          icon: Icons.receipt_long_outlined,
          label: 'My Quotes',
          onTap: () => _open(
            context,
            const QuotesListScreen(scope: RetailDocScope.mine),
          ),
        ),

        HomeActionChip(
          icon: Icons.receipt_outlined,
          label: 'My Invoices',
          onTap: () => _open(
            context,
            const InvoicesListScreen(scope: RetailDocScope.mine),
          ),
        ),
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final useTwoColumns =
            width > 0 && width < _gridBreakpoint && width >= 240;

        if (useTwoColumns) {
          final itemWidth = (width - AppShape.gap8) / 2;

          return Wrap(
            spacing: AppShape.gap8,
            runSpacing: AppShape.gap8,
            alignment: centered ? WrapAlignment.center : WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              for (final action in actions)
                SizedBox(
                  width: itemWidth,
                  child: Align(
                    alignment: centered
                        ? Alignment.center
                        : Alignment.centerLeft,
                    child: action,
                  ),
                ),
            ],
          );
        }

        return Wrap(
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppShape.gap10,
          runSpacing: AppShape.gap10,
          children: actions,
        );
      },
    );
  }

  // ─────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _openHealthMetrics(
    BuildContext context, {
    required String? contactId,
  }) async {
    final normalizedContactId = (contactId ?? '').trim();

    if (normalizedContactId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account is not linked to a contact.'),
        ),
      );
      return;
    }

    // Select an authorised health profile before
    // opening its measurements and trends.
    final profile = await Navigator.of(context).push<Profile>(
      MaterialPageRoute<Profile>(
        builder: (_) => ProfilesScreen(
          contactId: normalizedContactId,
          allowExplicitContactLink: false,
          selectionMode: true,
          selectionTitle: 'Select health profile',
        ),
      ),
    );

    if (profile == null || !context.mounted) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HealthMetricsDashboardScreen(
          initialProfile: profile,
          profilePickerContactId: normalizedContactId,
          memberMode: true,
        ),
      ),
    );
  }
}
