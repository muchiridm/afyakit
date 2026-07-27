// lib/core/home/widgets/member/member_features_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/widgets/shared/home_dashboard/home_shared.dart';
import 'package:afyakit/core/hq/tenants/models/feature_keys.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_profile_providers.dart';

import 'package:afyakit/features/clinical/profiles/models/profile_models.dart';
import 'package:afyakit/features/clinical/profiles/widgets/profiles_screen.dart';
import 'package:afyakit/features/clinical/prescriptions/widgets/prescriptions_screen.dart';
import 'package:afyakit/features/delivery_addresses/providers/delivery_address_providers.dart';
import 'package:afyakit/features/delivery_addresses/widgets/delivery_addresses_screen.dart';
import 'package:afyakit/features/health_metrics/widgets/health_metrics_dashboard_screen.dart';
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

  final AuthUser? user;
  final bool centered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactId = user?.contactId;
    final tenantProfile = ref.watch(tenantProfileProvider).valueOrNull;

    final healthMetricsEnabled =
        tenantProfile?.has(FeatureKeys.healthMetrics) == true;

    return Wrap(
      alignment: centered ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
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
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProfilesScreen(
                  contactId: contactId,
                  allowExplicitContactLink: false,
                ),
              ),
            );
          },
        ),
        HomeActionChip(
          icon: Icons.description_outlined,
          label: 'My Prescriptions',
          onTap: () {
            PrescriptionsScreen.open(context: context, contactId: contactId);
          },
        ),
        HomeActionChip(
          icon: Icons.location_on_outlined,
          label: 'Delivery Addresses',
          onTap: () {
            final scope = ref.read(currentUserDeliveryAddressScopeProvider);

            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    DeliveryAddressesScreen(scope: scope, memberMode: true),
              ),
            );
          },
        ),
        HomeActionChip(
          icon: Icons.receipt_long_outlined,
          label: 'My Quotes',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const QuotesListScreen(scope: RetailDocScope.mine),
              ),
            );
          },
        ),
        HomeActionChip(
          icon: Icons.receipt_outlined,
          label: 'My Invoices',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const InvoicesListScreen(scope: RetailDocScope.mine),
              ),
            );
          },
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

    if (profile == null || !context.mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HealthMetricsDashboardScreen(
          initialPatient: profile,
          profilePickerContactId: normalizedContactId,
          memberMode: true,
        ),
      ),
    );
  }
}
