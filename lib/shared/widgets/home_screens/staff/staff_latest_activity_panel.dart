// lib/shared/widgets/home_screens/staff/staff_latest_activity_panel.dart

import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:collection/collection.dart';
import 'package:afyakit/shared/models/activity_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/modules/inventory/locations/inventory_location_controller.dart';
import 'package:afyakit/modules/inventory/locations/inventory_location_type_enum.dart';
import 'package:afyakit/modules/inventory/records/deliveries/providers/delivery_records_stream_provider.dart';
import 'package:afyakit/modules/inventory/records/issues/providers/issue_streams_provider.dart';

import 'package:afyakit/modules/inventory/records/deliveries/widgets/delivery_record_tile.dart';
import 'package:afyakit/modules/inventory/records/issues/widgets/issue_record_tile.dart';

class StaffLatestActivityPanel extends ConsumerWidget {
  const StaffLatestActivityPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantSlugProvider);

    final issuesAsync = ref.watch(issuesStreamProvider(tenantId));
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

    // ── Loading state
    if (isLoading) {
      return const _LatestActivityShell(
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // ── Error state (403, etc) – DO NOT TOUCH `.value` here
    if (hasError) {
      return const _LatestActivityShell(
        child: Text(
          'Could not load staff activity for this tenant.',
          style: TextStyle(fontSize: 12, color: Colors.redAccent),
        ),
      );
    }

    // ── Safe to read valueOrNull now (no errors)
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

    final latest = entries
        .sorted((a, b) => b.date.compareTo(a.date))
        .take(3)
        .toList();

    if (latest.isEmpty) {
      return const _LatestActivityShell(
        child: Text(
          'No recent staff activity yet.',
          style: TextStyle(fontSize: 12),
        ),
      );
    }

    return _LatestActivityShell(
      child: Column(children: latest.map((entry) => entry.widget).toList()),
    );
  }
}

class _LatestActivityShell extends StatelessWidget {
  const _LatestActivityShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
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
        child,
      ],
    );
  }
}
