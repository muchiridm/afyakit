import 'package:afyakit/core/auth_users/providers/auth_session/current_user_providers.dart';
import 'package:afyakit/core/inventory_locations/inventory_location.dart';
import 'package:afyakit/core/batches/models/batch_record.dart';
import 'package:afyakit/core/inventory/models/item_type_enum.dart';
import 'package:afyakit/core/inventory_view/controllers/inventory_view_controller.dart';
import 'package:afyakit/core/inventory_view/utils/inventory_mode_enum.dart';
import 'package:afyakit/core/records/issues/controllers/cart/multi_cart_controller.dart';
import 'package:afyakit/core/auth_users/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_location_name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class BatchRow extends ConsumerWidget {
  final BatchRecord batch;
  final bool editable;
  final bool selectable;
  final dynamic item;
  final ItemType itemType;
  final InventoryMode mode;
  final List<InventoryLocation> stores;

  const BatchRow({
    super.key,
    required this.batch,
    required this.editable,
    required this.selectable,
    required this.item,
    required this.itemType,
    required this.mode,
    required this.stores,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(currentUserProvider);
    final cartState = ref.watch(multiCartProvider);
    final cartNotifier = ref.read(multiCartProvider.notifier);
    final controller = ref.read(
      inventoryViewControllerFamily(itemType).notifier,
    );

    final storeCart = cartState.cartFor(batch.storeId);
    final selectedQty =
        storeCart?.batchQuantities[batch.itemId]?[batch.id] ?? 0;

    return sessionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (user) {
        final isStockOut = mode.isStockOut;
        final canEdit = user?.canEditBatch(batch) ?? false;
        final canModifyQty = isStockOut || canEdit;
        final isExpired = _isBatchExpired(batch);
        final storeName = resolveLocationName(batch.storeId, stores, []);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildBatchInfo(storeName, isExpired)),
              if (selectable && canModifyQty)
                _buildQuantityControls(
                  cartNotifier,
                  batch.storeId,
                  selectedQty,
                ),
              if (editable && canEdit)
                ..._buildEditButton(context, user!, controller),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBatchInfo(String displayStoreName, bool isExpired) {
    final expiryLabel = batch.expiryDate != null
        ? DateFormat('yyyy-MM-dd').format(batch.expiryDate!)
        : 'No Expiry';

    final baseStyle = TextStyle(
      fontSize: 13.5,
      color: isExpired ? Colors.red : Colors.black87,
      fontWeight: isExpired ? FontWeight.bold : FontWeight.normal,
    );

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            displayStoreName,
            style: baseStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Text('${batch.quantity} pcs', style: baseStyle),
        const SizedBox(width: 12),
        Text(
          expiryLabel,
          style: baseStyle.copyWith(
            color: isExpired ? Colors.red : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityControls(
    MultiCartController cartNotifier,
    String storeId,
    int selectedQty,
  ) {
    return Row(
      children: [
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.remove, size: 18),
          onPressed: selectedQty > 0
              ? () => cartNotifier.updateQuantity(
                  storeId: storeId,
                  itemId: batch.itemId,
                  batchId: batch.id,
                  itemType: itemType,
                  qty: (selectedQty - 1).clamp(0, batch.quantity),
                )
              : null,
        ),
        Text('$selectedQty'),
        IconButton(
          icon: const Icon(Icons.add, size: 18),
          onPressed: selectedQty < batch.quantity
              ? () => cartNotifier.updateQuantity(
                  storeId: storeId,
                  itemId: batch.itemId,
                  batchId: batch.id,
                  itemType: itemType,
                  qty: (selectedQty + 1).clamp(0, batch.quantity),
                )
              : null,
        ),
      ],
    );
  }

  List<Widget> _buildEditButton(
    BuildContext context,
    AuthUser user,
    InventoryViewController controller,
  ) {
    return [
      const SizedBox(width: 8),
      IconButton(
        icon: const Icon(Icons.edit, size: 18, color: Colors.blueGrey),
        onPressed: () => controller.editBatch(context, batch, item, user),
      ),
    ];
  }

  bool _isBatchExpired(BatchRecord b) =>
      b.expiryDate != null && b.expiryDate!.isBefore(DateTime.now());
}
