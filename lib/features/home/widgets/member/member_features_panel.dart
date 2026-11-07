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
import 'package:afyakit/features/records/health_profiles/widgets/member_self_profile_screen.dart';
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
    // UI-only scope. Backend APIs must independently enforce
    // contact ownership and record-level access.
    //
    // Never use legacy AuthUser.contactId as canonical identity.
    final accountNumber = ref.watch(currentMemberAccountNumberProvider);

    // Application-level capability flags.
    final clinicalEnabled = ref.watch(appClinicalEnabledProvider);
    final healthMonitoringEnabled = ref.watch(
      appHealthMonitoringEnabledProvider,
    );
    final occupationalHealthEnabled = ref.watch(
      appOccupationalHealthEnabledProvider,
    );
    final pharmacyEnabled = ref.watch(appPharmacyEnabledProvider);
    final retailEnabled = ref.watch(appRetailEnabledProvider);

    final actions = <Widget>[
      // ─────────────────────────────────────
      // Core — identity and health profiles
      // ─────────────────────────────────────
      HomeActionChip(
        icon: Icons.people_alt_outlined,
        label: 'My Account',
        onTap: () => _open(context, MemberContactScreen(user: user)),
      ),

      HomeActionChip(
        icon: Icons.people_outline,
        label: occupationalHealthEnabled ? 'My Profile' : 'My Profiles',
        onTap: () {
          final account = _requireAccount(context, accountNumber);
          if (account == null) return;

          if (occupationalHealthEnabled) {
            _open(context, MemberSelfProfileScreen(accountNumber: account));
            return;
          }

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

      // ─────────────────────────────────────
      // Health Monitoring
      //
      // Independent of Clinical and Occuwell.
      // ─────────────────────────────────────
      if (healthMonitoringEnabled)
        HomeActionChip(
          icon: Icons.monitor_heart_outlined,
          label: 'My Health Metrics',
          onTap: () =>
              _openHealthMetrics(context, accountNumber: accountNumber),
        ),

      // ─────────────────────────────────────
      // Occupational Health
      //
      // Member-facing participation and records.
      // Does not expose staff MedEx workflows.
      // ─────────────────────────────────────
      if (occupationalHealthEnabled) ...[
        HomeActionChip(
          icon: Icons.assignment_outlined,
          label: 'My Campaigns',
          onTap: () => _openOccupationalHealth(
            context,
            accountNumber: accountNumber,
            title: 'My Campaigns',
            icon: Icons.assignment_outlined,
            description:
                'View your assigned occupational health campaigns '
                'and complete available screening questionnaires.',
          ),
        ),

        HomeActionChip(
          icon: Icons.medical_information_outlined,
          label: 'My MedEx',
          onTap: () => _openOccupationalHealth(
            context,
            accountNumber: accountNumber,
            title: 'My MedEx',
            icon: Icons.medical_information_outlined,
            description:
                'View occupational medical examinations and '
                'member-accessible examination information.',
          ),
        ),

        HomeActionChip(
          icon: Icons.verified_outlined,
          label: 'My Fitness Certificates',
          onTap: () => _openOccupationalHealth(
            context,
            accountNumber: accountNumber,
            title: 'My Fitness Certificates',
            icon: Icons.verified_outlined,
            description:
                'Access fitness certificates that have been '
                'issued and authorised for member viewing.',
          ),
        ),
      ],

      // ─────────────────────────────────────
      // Clinical
      // ─────────────────────────────────────
      if (clinicalEnabled)
        HomeActionChip(
          icon: Icons.description_outlined,
          label: 'My Prescriptions',
          onTap: () {
            final account = _requireAccount(context, accountNumber);
            if (account == null) return;

            // Legacy API parameter name; the supplied value
            // is the canonical AC-XXXXXX account number.
            PrescriptionsScreen.open(context: context, contactId: account);
          },
        ),

      // ─────────────────────────────────────
      // Pharmacy
      // ─────────────────────────────────────
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

    // Natural-width buttons, wrapping onto the next line as needed.
    return Wrap(
      alignment: centered ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppShape.gap10,
      runSpacing: AppShape.gap10,
      children: actions,
    );
  }

  // ─────────────────────────────────────
  // Canonical member identity
  // ─────────────────────────────────────

  String? _requireAccount(BuildContext context, String? value) {
    final account = value?.trim().toUpperCase();

    if (account != null &&
        RegExp(
          r'^AC-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$',
        ).hasMatch(account)) {
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

  // ─────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  // ─────────────────────────────────────
  // Health Monitoring
  // ─────────────────────────────────────

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
          // Legacy parameter name; canonical account value.
          profilePickerContactId: account,
          memberMode: true,
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  // Occupational Health
  // ─────────────────────────────────────

  void _openOccupationalHealth(
    BuildContext context, {
    required String? accountNumber,
    required String title,
    required IconData icon,
    required String description,
  }) {
    final account = _requireAccount(context, accountNumber);
    if (account == null) return;

    // Navigation placeholder until the member-scoped
    // campaign, MedEx and certificate screens are implemented.
    //
    // Do not reuse staff screens here: they have broader
    // clinical and employer-facing responsibilities.
    _open(
      context,
      _MemberOccupationalHealthPlaceholder(
        title: title,
        icon: icon,
        description: description,
      ),
    );
  }
}

/// Temporary member-facing landing page.
///
/// Replace with authenticated member-scoped screens when
/// their APIs and access controls are implemented.
class _MemberOccupationalHealthPlaceholder extends StatelessWidget {
  const _MemberOccupationalHealthPlaceholder({
    required this.title,
    required this.icon,
    required this.description,
  });

  final String title;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  'This section is not available yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
