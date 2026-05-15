// lib/core/home/widgets/staff/home_staff_body.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/widgets/dashboard/home_shared.dart';
import 'package:afyakit/core/home/widgets/dashboard/staff_components/staff_features_panel.dart';
import 'package:afyakit/core/home/widgets/activities/staff_latest_activity_panel.dart';
import 'package:afyakit/core/home/widgets/dashboard/staff_components/staff_primary_actions.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_profile_providers.dart';

import 'package:afyakit/features/clinical/patients/models/patient_profile_models.dart';
import 'package:afyakit/features/clinical/patients/patient_profiles_service.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_profile_form_dialog.dart';
import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';
import 'package:afyakit/features/retail/contacts/contacts_controller.dart';

import 'package:afyakit/shared/theme/app_shape.dart';

class HomeStaffBody extends ConsumerWidget {
  const HomeStaffBody({super.key, required this.user});

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

  void _openChatsInbox(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Staff chat inbox (TODO)')));
  }

  Future<void> _openAddPatientDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final input = await showDialog<PatientProfileUpsertInput>(
      context: context,
      builder: (_) =>
          const PatientProfileFormDialog(allowExplicitContactLink: true),
    );

    if (input == null || !context.mounted) return;

    try {
      final service = ref.read(patientProfilesServiceProvider);
      await service.create(input);

      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Patient profile created')));
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create patient profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantName = ref.watch(tenantDisplayNameProvider);

    final quickActions = StaffPrimaryActions(
      dense: true,
      onAddCustomer: () =>
          ref.read(contactsControllerProvider.notifier).openCreateFlow(context),
      onAddPatient: () => _openAddPatientDialog(context, ref),
      onRespondToChats: () => _openChatsInbox(context),
    );

    return homeVerticalStack([
      HomeDashboardTopBar(title: tenantName, trailing: quickActions),

      HomeDashboardTwoColumnLayout(
        leading: const StaffFeaturesPanel(),
        trailing: _StaffMainColumn(
          onSearch: (q) => _openCatalog(context, q: q),
          onBrowseCatalog: () => _openCatalog(context, autofocus: true),
        ),
      ),

      const SizedBox(height: AppShape.gap12),
    ], gap: AppShape.gap14);
  }
}

class _StaffMainColumn extends StatelessWidget {
  const _StaffMainColumn({
    required this.onSearch,
    required this.onBrowseCatalog,
  });

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
          hintText: 'Search medicines, brands, patients, customers…',
          footerText: 'Search the catalog while serving a customer',
          onSearch: onSearch,
          onBrowse: onBrowseCatalog,
        ),
      ),

      const QuietHomePanel(child: StaffLatestActivityPanel()),
    ], gap: AppShape.gap14);
  }
}
