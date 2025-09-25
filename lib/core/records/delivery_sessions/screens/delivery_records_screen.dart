import 'package:afyakit/shared/screens/grouped_records_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/inventory_locations/inventory_location.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_controller.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_type_enum.dart';
import 'package:afyakit/core/records/delivery_sessions/models/delivery_record.dart';
import 'package:afyakit/core/records/delivery_sessions/widgets/delivery_record_tile.dart';
import 'package:afyakit/hq/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/core/records/delivery_sessions/providers/delivery_records_stream_provider.dart';

class DeliveryRecordsScreen extends ConsumerWidget {
  const DeliveryRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final deliveriesAsync = ref.watch(deliveryRecordsStreamProvider(tenantId));
    final stores = ref
        .watch(inventoryLocationProvider(InventoryLocationType.store))
        .maybeWhen(data: (d) => d, orElse: () => <InventoryLocation>[]);

    return GroupedRecordsScreen<DeliveryRecord>(
      title: 'Delivery Records',
      maxContentWidth: 800,
      recordsAsync: deliveriesAsync,
      dateExtractor: (r) => r.date,
      recordTileBuilder: (record) =>
          DeliveryRecordTile(record: record, stores: stores),
    );
  }
}
