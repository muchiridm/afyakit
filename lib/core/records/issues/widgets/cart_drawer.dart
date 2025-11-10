import 'package:afyakit/core/inventory_locations/inventory_location.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_controller.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_type_enum.dart';
import 'package:afyakit/core/records/issues/models/view_models/cart_item_models.dart';
import 'package:afyakit/core/records/issues/controllers/cart/multi_cart_controller.dart';
import 'package:afyakit/core/records/issues/providers/grouped_cart_provider.dart';
import 'package:afyakit/core/records/issues/widgets/screens/issue_request_screen.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_location_name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartDrawer extends ConsumerWidget {
  final String action;

  const CartDrawer({super.key, required this.action});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // controller still needed for actions (e.g., remove)
    final controller = ref.read(multiCartProvider.notifier);

    // 🔁 watch the derived grouped view so UI reacts instantly to changes
    final displayItemsByStore = ref.watch(groupedCartProvider);

    // stores list as before
    final stores = ref
        .watch(inventoryLocationProvider(InventoryLocationType.store))
        .maybeWhen(data: (d) => d, orElse: () => const <InventoryLocation>[]);

    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Expanded(
              child: displayItemsByStore.isEmpty
                  ? const Center(child: Text('No items selected.'))
                  : _buildGroupedCartList(
                      context,
                      controller,
                      displayItemsByStore,
                      stores,
                    ),
            ),
            _buildCheckoutButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'Selected Items',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildGroupedCartList(
    BuildContext context,
    MultiCartController controller,
    Map<String, List<CartDisplayItem>> displayItemsByStore,
    List<InventoryLocation> stores,
  ) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: displayItemsByStore.entries.map((entry) {
        final storeId = entry.key;
        final items = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏪 Store: ${resolveLocationName(storeId, stores, [])}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => _buildCartItemCard(context, controller, item, stores),
            ),
            const Divider(height: 24),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCartItemCard(
    BuildContext context,
    MultiCartController controller,
    CartDisplayItem item,
    List<InventoryLocation> stores,
  ) {
    final subtitle = item.subtitle.isNotEmpty
        ? resolveLocationName(item.subtitle, stores, [])
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.label} • [${item.itemType.name}]',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13.5, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 8),
            ...item.batches.map(
              (batch) => _buildBatchRow(controller, item.itemId, batch, stores),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchRow(
    MultiCartController controller,
    String itemId,
    CartDisplayBatch batch,
    List<InventoryLocation> stores,
  ) {
    final storeName = resolveLocationName(batch.storeId, stores, []);

    // Rewrite the label to prefer the human-readable store name.
    String displayLabel;
    if (batch.label == batch.storeId) {
      displayLabel = storeName;
    } else if (batch.label.startsWith(batch.storeId)) {
      displayLabel = storeName + batch.label.substring(batch.storeId.length);
    } else {
      // If the label doesn't include the id, prepend the store name for clarity.
      displayLabel = '$storeName ${batch.label}'.trim();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(displayLabel, style: const TextStyle(fontSize: 13.5)),
          ),
          Row(
            children: [
              Text('Qty: ${batch.quantity}'),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => controller.remove(
                  itemId: itemId,
                  batchId: batch.batchId,
                  storeId: batch.storeId, // ✅ still needed for removal
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.send),
        label: const Text('Proceed to Checkout'),
        onPressed: () {
          Navigator.of(context).pop();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const IssueRequestScreen()));
        },
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
