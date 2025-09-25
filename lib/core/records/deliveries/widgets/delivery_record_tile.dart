// lib/shared/widgets/delivery_record_tile.dart

import 'package:afyakit/core/inventory_locations/inventory_location.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_type_enum.dart';
import 'package:flutter/material.dart';
import 'package:afyakit/core/records/deliveries/models/delivery_record.dart';
import 'package:afyakit/core/records/deliveries/screens/delivery_details_screen.dart';
import 'package:afyakit/shared/utils/format/format_date.dart';

class DeliveryRecordTile extends StatelessWidget {
  final DeliveryRecord record;
  final List<InventoryLocation> stores;

  const DeliveryRecordTile({
    super.key,
    required this.record,
    required this.stores,
  });

  @override
  Widget build(BuildContext context) {
    final fromStores = record.sources
        .map(
          (id) => stores
              .firstWhere(
                (s) => s.id == id,
                orElse: () => InventoryLocation(
                  id: id,
                  tenantId: 'unknown',
                  name: id,
                  type: InventoryLocationType.store,
                ),
              )
              .name,
        )
        .join(', ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      elevation: 1,
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: CircleAvatar(
          backgroundColor: Colors.teal.withOpacity(0.15),
          child: const Icon(Icons.local_shipping, color: Colors.teal, size: 20),
        ),
        title: Text(record.deliveryId),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${record.itemCount} items • ${record.totalQuantity} units • From: $fromStores',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(formatDate(record.date), style: const TextStyle(fontSize: 11)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                DeliveryDetailScreen(summary: record, stores: stores),
          ),
        ),
      ),
    );
  }
}
