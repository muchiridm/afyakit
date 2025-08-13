import 'package:afyakit/shared/utils/normalize/normalize_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/batches/models/batch_record.dart';
import 'package:afyakit/features/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/features/inventory/models/item_type_enum.dart';
import 'package:afyakit/features/inventory_view/utils/inventory_mode_enum.dart';
import 'package:afyakit/features/inventory_view/widgets/inventory_browser_components/inventory_list_view.dart';
import 'package:afyakit/features/inventory_view/widgets/inventory_browser_components/stock_search_bar.dart';

class InventoryBrowser extends ConsumerWidget {
  final List<BaseInventoryItem> items;
  final Map<String, List<BatchRecord>> matcher;

  final String query;
  final bool sortAscending;
  final bool isLoading;
  final String? error;

  final bool enableSelectionCart;
  final bool showBatches;
  final ItemType type;
  final InventoryMode mode;

  final Map<String, Map<String, int>>? batchQuantities;
  final void Function(String itemId, String batchId, int qty)? onQtyChange;
  final void Function(String itemId)? onAddToCart;
  final void Function(String) onQueryChanged;
  final VoidCallback onSortToggle;

  const InventoryBrowser({
    super.key,
    required this.items,
    required this.matcher,

    required this.query,
    required this.sortAscending,
    required this.isLoading,
    required this.error,
    required this.type,
    required this.mode,
    required this.onQueryChanged,
    required this.onSortToggle,
    this.enableSelectionCart = false,
    this.showBatches = true,
    this.batchQuantities,
    this.onQtyChange,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(height: 8),
            Text(
              error ?? 'An unknown error occurred.',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final relevantBatches = {
      for (final item in items)
        if (item.id != null) item.id!: matcher[item.id!.normalize()] ?? [],
    };

    // Pre-fill batch quantities with live values if not provided
    final autoBatchQuantities = {
      for (final entry in relevantBatches.entries)
        entry.key: {
          ...?batchQuantities?[entry.key],
          for (final b in entry.value)
            if (!(batchQuantities?[entry.key]?.containsKey(b.id) ?? false))
              b.id: b.quantity,
        },
    };

    return Column(
      children: [
        _buildSearchBar(query),
        const SizedBox(height: 8),
        Expanded(
          child: InventoryListView(
            items: items,
            batchesBySku: relevantBatches,
            query: query,
            sortAscending: sortAscending,
            enableSelectionCart: enableSelectionCart,
            batchQuantities: autoBatchQuantities,
            onQtyChange: onQtyChange,
            onAddToCart: onAddToCart,
            mode: mode, // 👈 passed down
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(String initialQuery) {
    return StatefulBuilder(
      builder: (context, setState) {
        final controller = TextEditingController(text: initialQuery)
          ..selection = TextSelection.collapsed(offset: initialQuery.length);

        return StockSearchBar(
          controller: controller,
          sortAscending: sortAscending,
          onChanged: (val) => onQueryChanged(val),
          onSortToggle: onSortToggle,
        );
      },
    );
  }
}
