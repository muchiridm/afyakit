import 'package:afyakit/shared/widgets/records/grouped_records_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/inventory_locations/inventory_location.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_controller.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_type_enum.dart';
import 'package:afyakit/core/records/issues/models/issue_record.dart';
import 'package:afyakit/hq/tenants/v2/providers/tenant_slug_provider.dart';
import 'package:afyakit/core/records/issues/providers/issue_streams_provider.dart';
import 'package:afyakit/core/records/issues/widgets/issue_record_tile.dart';

class IssueRecordsScreen extends ConsumerWidget {
  const IssueRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantSlugProvider);
    final asyncIssues = ref.watch(issuesStreamProvider(tenantId));

    final stores = ref
        .watch(inventoryLocationProvider(InventoryLocationType.store))
        .maybeWhen(data: (d) => d, orElse: () => <dynamic>[])
        .cast<InventoryLocation>();
    final dispensaries = ref
        .watch(inventoryLocationProvider(InventoryLocationType.dispensary))
        .maybeWhen(data: (d) => d, orElse: () => <dynamic>[])
        .cast<InventoryLocation>();

    return GroupedRecordsScreen<IssueRecord>(
      title: 'Issue Records',
      maxContentWidth: 800,
      recordsAsync: asyncIssues,
      dateExtractor: (record) =>
          record.dateIssuedOrReceived ?? record.dateRequested,
      recordTileBuilder: (record) => IssueRecordTile(
        issue: record,
        stores: stores,
        dispensaries: dispensaries,
        compact: true,
      ),
    );
  }
}
