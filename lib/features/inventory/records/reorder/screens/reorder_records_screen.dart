import 'package:afyakit/features/inventory/items/providers/all_inventory_map_provider.dart';
import 'package:afyakit/features/inventory/records/reorder/models/reorder_record.dart';
import 'package:afyakit/features/inventory/records/reorder/screens/reorder_details_screen.dart';
import 'package:afyakit/features/inventory/records/reorder/providers/reorder_records_provider.dart';
import 'package:afyakit/features/inventory/records/shared/grouped_records_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReorderRecordsScreen extends ConsumerWidget {
  const ReorderRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(reorderRecordsProvider);
    final itemMapAsync = ref.watch(allInventoryMapProvider); // ✅ read itemMap

    // 🛑 Wait until itemMap is loaded
    if (itemMapAsync.isLoading || itemMapAsync.hasError) {
      return const Center(child: CircularProgressIndicator());
    }

    final itemMap = itemMapAsync.value!; // ✅ now it's available

    return GroupedRecordsScreen<ReorderRecord>(
      title: 'Reorder Records',
      recordsAsync: recordsAsync,
      maxContentWidth: 800,
      dateExtractor: (record) => record.createdAt,
      recordTileBuilder: (record) => ListTile(
        title: Text('PO ${record.id}'),
        subtitle: Text(
          '${record.itemCount} items • ${record.type.label} • Exported by ${record.exportedByName}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ReorderDetailScreen(record: record, itemMap: itemMap),
            ),
          );
        },
      ),
    );
  }
}
