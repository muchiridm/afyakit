import 'package:afyakit/core/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/core/records/reorder/models/reorder_item.dart';
import 'package:afyakit/core/records/reorder/models/reorder_record.dart';
import 'package:afyakit/shared/widgets/records/detail_record_screen.dart';
import 'package:afyakit/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';

class ReorderDetailScreen extends StatelessWidget {
  final ReorderRecord record;
  final Map<String, BaseInventoryItem> itemMap;

  const ReorderDetailScreen({
    super.key,
    required this.record,
    required this.itemMap,
  });

  @override
  Widget build(BuildContext context) {
    return DetailRecordScreen(
      maxContentWidth: 900,
      header: ScreenHeader('Reorder: ${record.id}', showBack: true),

      contentSections: [
        _buildMetaCard(record),
        _buildItemsList(record, itemMap),
      ],
    );
  }

  Widget _buildMetaCard(ReorderRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Exported by ${record.exportedByName}'),
                  const SizedBox(height: 4),
                  Text(
                    'Created on ${record.createdAt}',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
            Chip(label: Text(record.type.name)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList(
    ReorderRecord record,
    Map<String, BaseInventoryItem> itemMap,
  ) {
    final grouped = <String, List<ReorderItem>>{};

    for (final item in record.items) {
      final type = item.itemType.name;
      grouped.putIfAbsent(type, () => []).add(item);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (final entry in grouped.entries) ...[
              Text(
                entry.key,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              for (final reorderItem in entry.value)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    _buildItemText(reorderItem, itemMap),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  String _buildItemText(
    ReorderItem reorderItem,
    Map<String, BaseInventoryItem> itemMap,
  ) {
    final item = itemMap[reorderItem.itemId];
    final name = item?.name ?? 'Unknown Item';
    final brand = item?.name.isNotEmpty == true
        ? ' • Brand: ${item!.name}'
        : '';
    return '$name\nQty: ${reorderItem.quantity}$brand';
  }
}
