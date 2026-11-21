// lib/features/home/widgets/member/member_features_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/providers/app_feature_providers.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/features/clinical/prescriptions/widgets/prescriptions_screen.dart';
import 'package:afyakit/features/records/delivery_addresses/providers/delivery_address_providers.dart';
import 'package:afyakit/features/records/delivery_addresses/widgets/delivery_addresses_screen.dart';
import 'package:afyakit/features/home/widgets/shared/home_dashboard/home_shared.dart';
import 'package:afyakit/features/records/native_contacts/member_native_contact_provider.dart';
import 'package:afyakit/features/records/native_contacts/widgets/member_contact_screen.dart';
import 'package:afyakit/features/records/health_metrics/widgets/health_metrics_dashboard_screen.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profiles_screen.dart';
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
    // UI-only scope. The API independently verifies contact ownership.
    // NEVER use the legacy AuthUser.contactId for Native Contact identity.
    final accountNumber = ref.watch(currentMemberAccountNumberProvider);
    final clinicalEnabled = ref.watch(appClinicalEnabledProvider);
    final pharmacyEnabled = ref.watch(appPharmacyEnabledProvider);
    final retailEnabled = ref.watch(appRetailEnabledProvider);

    final actions = <Widget>[
      HomeActionChip(
        icon: Icons.people_alt_outlined,
        label: 'My Contact',
        onTap: () => _open(context, MemberContactScreen(user: user)),
      ),
      HomeActionChip(
        icon: Icons.people_outline,
        label: 'My Profiles',
        onTap: () {
          final account = _requireAccount(context, accountNumber);
          if (account == null) return;
          _open(
            context,
            ProfilesScreen(
              accountNumber: account,
              memberMode: true,
              allowExplicitContactLink: false,
            ),
          );
        },
      ),
      HomeActionChip(
        icon: Icons.monitor_heart_outlined,
        label: 'My Health Metrics',
        onTap: () => _openHealthMetrics(
          context,
          accountNumber: accountNumber,
        ),
      ),
      if (clinicalEnabled)
        HomeActionChip(
          icon: Icons.description_outlined,
          label: 'My Prescriptions',
          onTap: () {
            final account = _requireAccount(context, accountNumber);
            if (account == null) return;
            // The existing prescriptions API uses `contactId` as its argument
            // name, but the value is the canonical AC-XXXXXX account number.
            PrescriptionsScreen.open(context: context, contactId: account);
          },
        ),
      if (pharmacyEnabled)
        HomeActionChip(
          icon: Icons.location_on_outlined,
          label: 'Delivery Addresses',
          onTap: () {
            final account = _requireAccount(context, accountNumber);
            if (account == null) return;
            final scope = ref.read(currentUserDeliveryAddressScopeProvider);
            _open(
              context,
              DeliveryAddressesScreen(scope: scope, memberMode: true),
            );
          },
        ),
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
                    alignment:
                        centered ? Alignment.center : Alignment.centerLeft,
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

  String? _requireAccount(BuildContext context, String? value) {
    final account = value?.trim().toUpperCase();
    if (account != null &&
        RegExp(r'^AC-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$')
            .hasMatch(account)) {
      return account;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Your Native Contact account is not available yet. '
          'Please refresh your account or sign in again.',
        ),
      ),
    );
    return null;
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _openHealthMetrics(
    BuildContext context, {
    required String? accountNumber,
  }) async {
    final account = _requireAccount(context, accountNumber);
    if (account == null) return;

    final profile = await Navigator.of(context).push<Profile>(
      MaterialPageRoute<Profile>(
        builder: (_) => ProfilesScreen(
          accountNumber: account,
          memberMode: true,
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
          initialProfile: profile,
          // Legacy constructor parameter name; value is canonical account.
          profilePickerContactId: account,
          memberMode: true,
        ),
      ),
    );
  }
}
