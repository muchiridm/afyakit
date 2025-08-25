import 'package:collection/collection.dart';
import 'package:afyakit/shared/models/activity_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/inventory_locations/inventory_location_controller.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_type_enum.dart';
import 'package:afyakit/features/records/delivery_sessions/providers/delivery_records_stream_provider.dart';
import 'package:afyakit/features/records/issues/providers/issues_stream_provider.dart';
import 'package:afyakit/features/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/features/records/delivery_sessions/widgets/delivery_record_tile.dart';
import 'package:afyakit/features/records/issues/widgets/issue_record_tile.dart';

class LatestActivityPanel extends ConsumerWidget {
  const LatestActivityPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);

    final issuesAsync = ref.watch(hydratedIssuesStreamProvider(tenantId));
    final deliveriesAsync = ref.watch(deliveryRecordsStreamProvider(tenantId));
    final storesAsync = ref.watch(
      inventoryLocationProvider(InventoryLocationType.store),
    );
    final dispensariesAsync = ref.watch(
      inventoryLocationProvider(InventoryLocationType.dispensary),
    );

    final isLoading =
        issuesAsync.isLoading ||
        deliveriesAsync.isLoading ||
        storesAsync.isLoading ||
        dispensariesAsync.isLoading;
    final hasError =
        issuesAsync.hasError ||
        deliveriesAsync.hasError ||
        storesAsync.hasError ||
        dispensariesAsync.hasError;

    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (hasError) return const SizedBox.shrink();

    final issues = issuesAsync.value ?? [];
    final deliveries = deliveriesAsync.value ?? [];
    final stores = storesAsync.value ?? [];
    final dispensaries = dispensariesAsync.value ?? [];

    final entries = [
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

    final latest = entries
        .sorted((a, b) => b.date.compareTo(a.date))
        .take(3)
        .toList();

    if (latest.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            '🔔 Latest Activity',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...latest.map((entry) => entry.widget),
      ],
    );
  }
}
