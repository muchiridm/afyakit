// lib/core/home/widgets/staff/staff_latest_activity_panel.dart

import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_feature_providers.dart';
import 'package:afyakit/core/home/models/activity_entry.dart';
import 'package:afyakit/core/home/widgets/latest_activity_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/inventory/locations/inventory_location_controller.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_type_enum.dart';
import 'package:afyakit/features/inventory/records/deliveries/providers/delivery_records_stream_provider.dart';
import 'package:afyakit/features/inventory/records/issues/providers/issue_streams_provider.dart';

import 'package:afyakit/features/inventory/records/deliveries/widgets/delivery_record_tile.dart';
import 'package:afyakit/features/inventory/records/issues/widgets/issue_record_tile.dart';

class StaffLatestActivityPanel extends ConsumerWidget {
  const StaffLatestActivityPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final inventoryEnabled = ref.watch(tenantInventoryEnabledProvider);

    if (!inventoryEnabled) {
      return const LatestActivityPanel(
        title: 'Latest Activity',
        icon: Icons.notifications_none,
        loading: false,
        hasError: false,
        entries: [],
        emptyText:
            'No staff activity to show (Inventory is disabled for this tenant).',
      );
    }

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

    final issues = issuesAsync.valueOrNull ?? [];
    final deliveries = deliveriesAsync.valueOrNull ?? [];
    final stores = storesAsync.valueOrNull ?? [];
    final dispensaries = dispensariesAsync.valueOrNull ?? [];

    final entries = <ActivityEntry>[
      ...issues.map(
        (issue) => ActivityEntry(
          date: issue.dateIssuedOrReceived ?? issue.dateRequested,
          widget: IssueRecordTile(
            issue: issue,
            stores: stores,
            dispensaries: dispensaries,
          ),
        ),
      ),
      ...deliveries.map(
        (delivery) => ActivityEntry(
          date: delivery.date,
          widget: DeliveryRecordTile(record: delivery, stores: stores),
        ),
      ),
    ];

    return LatestActivityPanel(
      title: 'Latest Activity',
      icon: Icons.notifications_none,
      loading: loading,
      hasError: hasError,
      entries: entries,
      emptyText: 'No recent staff activity yet.',
      maxItems: 5,
    );
  }
}
