import 'package:afyakit/core/records/issues/controllers/cart/multi_cart_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartView extends ConsumerWidget {
  const CartView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final multiCart = ref.watch(multiCartProvider);

    if (multiCart.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Cart is empty'),
      );
    }

    return Container(
      color: Colors.blueGrey.shade50,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cart Items (Grouped by Store)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),

          ...multiCart.cartsByStore.entries.map((storeEntry) {
            final storeId = storeEntry.key;
            final cart = storeEntry.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🏪 Store: $storeId',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                ...cart.batchQuantities.entries.map((itemEntry) {
                  final itemId = itemEntry.key;
                  final batches = itemEntry.value;

                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• $itemId'),
                        ...batches.entries.map((e) {
                          final batchId = e.key;
                          final qty = e.value;
                          return Padding(
                            padding: const EdgeInsets.only(left: 16, top: 2),
                            child: Text('- Batch $batchId → Qty: $qty'),
                          );
                        }),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                }),
                const Divider(height: 24),
              ],
            );
          }),
        ],
      ),
    );
  }
}
