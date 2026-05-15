// lib/core/home/widgets/activities/staff_latest_activity_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/home/models/activity_entry.dart';
import 'package:afyakit/core/home/widgets/activities/latest_activity_panel.dart';
import 'package:afyakit/core/home/widgets/activities/patient_activity_adapter.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_feature_providers.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';

import 'package:afyakit/features/clinical/patients/models/patient_link_request_models.dart';
import 'package:afyakit/features/clinical/patients/models/patient_profile_models.dart';
import 'package:afyakit/features/clinical/patients/patient_profiles_service.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_controller.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_type_enum.dart';
import 'package:afyakit/features/inventory/records/deliveries/providers/delivery_records_stream_provider.dart';
import 'package:afyakit/features/inventory/records/deliveries/widgets/delivery_record_tile.dart';
import 'package:afyakit/features/inventory/records/issues/providers/issue_streams_provider.dart';
import 'package:afyakit/features/inventory/records/issues/widgets/issue_record_tile.dart';

class StaffLatestActivityPanel extends ConsumerWidget {
  const StaffLatestActivityPanel({super.key});

  static const int _maxItems = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final inventoryEnabled = ref.watch(tenantInventoryEnabledProvider);

    final inventoryResult = inventoryEnabled
        ? _watchInventoryActivity(ref, tenantId)
        : const _ActivityResult.empty();

    final patientsAsync = ref.watch(_staffPatientActivityProvider);

    final patientBundle = patientsAsync.valueOrNull;
    final patientEntries = patientBundle?.entries ?? const <ActivityEntry>[];

    final entries = <ActivityEntry>[
      ...inventoryResult.entries,
      ...patientEntries,
      // Contacts will plug in here next:
      // ...contactEntries,
    ];

    return LatestActivityPanel(
      title: 'Latest Activity',
      icon: Icons.notifications_none,
      loading: inventoryResult.loading || patientsAsync.isLoading,
      hasError: inventoryResult.hasError || patientsAsync.hasError,
      entries: entries,
      emptyText: 'No recent staff activity yet.',
      maxItems: _maxItems,
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

final _staffPatientActivityProvider =
    FutureProvider.autoDispose<_PatientActivityBundle>((ref) async {
      final service = ref.watch(patientProfilesServiceProvider);

      final results = await Future.wait<Object>([
        service.list(),
        service.listLinkRequests(),
      ]);

      final patients = results[0] as List<PatientProfile>;
      final linkRequests = results[1] as List<PatientLinkRequest>;

      return _PatientActivityBundle(
        patients: patients,
        linkRequests: linkRequests,
      );
    });

class _PatientActivityBundle {
  const _PatientActivityBundle({
    required this.patients,
    required this.linkRequests,
  });

  final List<PatientProfile> patients;
  final List<PatientLinkRequest> linkRequests;

  List<ActivityEntry> get entries {
    return <ActivityEntry>[
      ...PatientActivityAdapter.fromPatients(patients),
      ...PatientActivityAdapter.fromLinkRequests(linkRequests),
    ];
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
