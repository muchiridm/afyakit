// lib/core/home/activities/shared/staff_latest_activity_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/home/models/activity_entry.dart';
import 'package:afyakit/core/home/activities/contacts/contact_activity_adapter.dart';
import 'package:afyakit/core/home/activities/contacts/contact_activity_providers.dart';
import 'package:afyakit/core/home/activities/patients/patient_activity_adapter.dart';
import 'package:afyakit/core/home/activities/patients/patient_activity_providers.dart';
import 'package:afyakit/core/home/activities/quotes/quote_activity_adapter.dart';
import 'package:afyakit/core/home/activities/quotes/quote_activity_providers.dart';
import 'package:afyakit/core/home/activities/shared/latest_activity_panel.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_feature_providers.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';

import 'package:afyakit/features/clinical/patients/widgets/patient_details_screen.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_profiles_screen.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_controller.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_type_enum.dart';
import 'package:afyakit/features/inventory/records/deliveries/providers/delivery_records_stream_provider.dart';
import 'package:afyakit/features/inventory/records/deliveries/widgets/delivery_record_tile.dart';
import 'package:afyakit/features/inventory/records/issues/providers/issue_streams_provider.dart';
import 'package:afyakit/features/inventory/records/issues/widgets/issue_record_tile.dart';
import 'package:afyakit/features/retail/contacts/widgets/contacts_screen.dart';
import 'package:afyakit/features/retail/quotes/widgets/quote_detail_screen.dart';

class StaffLatestActivityPanel extends ConsumerWidget {
  const StaffLatestActivityPanel({
    super.key,
    this.maxItems = 10,
    this.onTitleTap,
    this.title = 'Latest Activity',
    this.emptyText = 'No recent staff activity yet.',
  });

  final int? maxItems;
  final VoidCallback? onTitleTap;
  final String title;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final inventoryEnabled = ref.watch(tenantInventoryEnabledProvider);

    final inventoryResult = inventoryEnabled
        ? _watchInventoryActivity(ref, tenantId)
        : const _ActivityResult.empty();

    final patientsAsync = ref.watch(staffPatientActivityProvider);
    final quotesAsync = ref.watch(staffSubmittedQuoteActivityProvider);
    final customersAsync = ref.watch(staffCustomerActivityProvider);

    final patientBundle = patientsAsync.valueOrNull;

    final patientEntries = <ActivityEntry>[
      ...PatientActivityAdapter.fromPatients(
        patientBundle?.patients ?? const [],
        onTapForPatient: (patient) {
          return () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PatientDetailsScreen(
                patient: patient,
                allowExplicitContactLink: true,
              ),
            ),
          );
        },
      ),
      ...PatientActivityAdapter.fromLinkRequests(
        patientBundle?.linkRequests ?? const [],
        onTapForRequest: (_) {
          return () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const PatientProfilesScreen(allowExplicitContactLink: true),
            ),
          );
        },
      ),
    ];

    final quoteEntries = QuoteActivityAdapter.fromSubmittedQuotes(
      quotesAsync.valueOrNull ?? const [],
      onTapForQuote: (quote) {
        final quoteId = quote.quoteId.trim();
        if (quoteId.isEmpty) return null;

        return () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                QuoteDetailScreen(quoteId: quoteId, forceStaffWorkspace: true),
          ),
        );
      },
    );

    final customerEntries = ContactActivityAdapter.fromCustomers(
      customersAsync.valueOrNull ?? const [],
      onTapForContact: (contact) {
        final contactId = contact.contactId.trim();
        if (contactId.isEmpty) return null;

        return () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ContactsScreen()));
      },
    );

    final entries = <ActivityEntry>[
      ...inventoryResult.entries,
      ...patientEntries,
      ...quoteEntries,
      ...customerEntries,
    ];

    return LatestActivityPanel(
      title: title,
      icon: Icons.notifications_none,
      loading:
          inventoryResult.loading ||
          patientsAsync.isLoading ||
          quotesAsync.isLoading ||
          customersAsync.isLoading,
      hasError:
          inventoryResult.hasError ||
          patientsAsync.hasError ||
          quotesAsync.hasError ||
          customersAsync.hasError,
      entries: entries,
      emptyText: emptyText,
      maxItems: maxItems,
      onTitleTap: onTitleTap,
    );
  }

  _ActivityResult _watchInventoryActivity(WidgetRef ref, String tenantId) {
    final issuesAsync = ref.watch(issuesStreamProvider(tenantId));
    final deliveriesAsync = ref.watch(deliveryRecordsStreamProvider(tenantId));

    final storesAsync = ref.watch(
      inventoryLocationProvider(InventoryLocationType.store),
    );
    final dispensariesAsync = ref.watch(
      inventoryLocationProvider(InventoryLocationType.dispensary),
    );

    final loading =
        issuesAsync.isLoading ||
        deliveriesAsync.isLoading ||
        storesAsync.isLoading ||
        dispensariesAsync.isLoading;

    final hasError =
        issuesAsync.hasError ||
        deliveriesAsync.hasError ||
        storesAsync.hasError ||
        dispensariesAsync.hasError;

    final stores = storesAsync.valueOrNull ?? const [];
    final dispensaries = dispensariesAsync.valueOrNull ?? const [];

    final entries = <ActivityEntry>[
      for (final issue in issuesAsync.valueOrNull ?? const [])
        ActivityEntry(
          date: issue.dateIssuedOrReceived ?? issue.dateRequested,
          widget: IssueRecordTile(
            issue: issue,
            stores: stores,
            dispensaries: dispensaries,
          ),
        ),
      for (final delivery in deliveriesAsync.valueOrNull ?? const [])
        ActivityEntry(
          date: delivery.date,
          widget: DeliveryRecordTile(record: delivery, stores: stores),
        ),
    ];

    return _ActivityResult(
      loading: loading,
      hasError: hasError,
      entries: entries,
    );
  }
}

class _ActivityResult {
  const _ActivityResult({
    required this.loading,
    required this.hasError,
    required this.entries,
  });

  const _ActivityResult.empty()
    : loading = false,
      hasError = false,
      entries = const <ActivityEntry>[];

  final bool loading;
  final bool hasError;
  final List<ActivityEntry> entries;
}
