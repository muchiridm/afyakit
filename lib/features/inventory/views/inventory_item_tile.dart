import 'package:flutter/material.dart';

import 'package:afyakit/features/inventory/batches/inventory_batch.dart';
import 'package:afyakit/features/inventory/items/inventory_item.dart';
import 'package:afyakit/features/inventory/locations/inventory_location.dart';

/// Display-only item row. Stock selection is controlled by StockScreen.
class InventoryItemTile extends StatelessWidget {
  const InventoryItemTile({
    super.key,
    required this.item,
    required this.batches,
    required this.locations,
    required this.stockOut,
    required this.onSelectBatch,
  });

  final InventoryItem item;
  final List<InventoryBatch> batches;
  final List<InventoryLocation> locations;
  final bool stockOut;
  final void Function(InventoryBatch batch)? onSelectBatch;

  String _locationName(String storeId) {
    for (final location in locations) {
      if (location.id == storeId) {
        return location.name.trim().isNotEmpty
            ? location.name
            : 'Unnamed location';
      }
    }

    return 'Unknown location';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quantity = batches.fold<num>(0, (sum, batch) => sum + batch.quantity);

    // Group is a dynamic attribute, not a top-level InventoryItem field.
    final rawGroup = item.attributes['group'];

    final groups = rawGroup is List
        ? rawGroup.whereType<String>().where((g) => g.isNotEmpty).join(', ')
        : rawGroup is String
        ? rawGroup.trim()
        : '';

    final category = groups.isNotEmpty ? groups : item.itemType;

    return Card(
      child: ExpansionTile(
        title: Text(item.name.isEmpty ? item.id : item.name),
        subtitle: Text(
          '$category • ${batches.length} batches • Recorded: $quantity',
        ),
        children: [
          if (batches.isEmpty)
            const ListTile(title: Text('No batches in this store')),
          for (final batch in batches)
            ListTile(
              title: Text(
                batch.batchNumber?.trim().isNotEmpty == true
                    ? batch.batchNumber!
                    : 'Batch number not specified',
              ),
              subtitle: Text(
                'Location: ${_locationName(batch.storeId)}'
                ' • Recorded quantity: ${batch.quantity}'
                '${batch.expiryDate == null ? '' : ' • Expiry: ${batch.expiryDate}'}',
              ),
              trailing: stockOut
                  ? IconButton(
                      tooltip: 'Add batch to issue cart',
                      icon: Icon(
                        Icons.add_shopping_cart,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: batch.quantity > 0 && !batch.isArchived
                          ? () => onSelectBatch?.call(batch)
                          : null,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}
