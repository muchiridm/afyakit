import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/features/inventory/items/inventory_item.dart';
import 'package:afyakit/features/inventory/items/inventory_items_providers.dart';
import 'inventory_reorder.dart';
import 'inventory_reorders_service.dart';

final inventoryReordersServiceProvider =
    FutureProvider<InventoryReordersService>((ref) async {
      final items = await ref.watch(inventoryItemsServiceProvider.future);
      return InventoryReordersService(items);
    });

final inventoryReorderItemsProvider = FutureProvider<List<InventoryItem>>((
  ref,
) async {
  final service = await ref.watch(inventoryReordersServiceProvider.future);
  return service.listOrderableItems();
});

/// Not persisted. A fresh app/tenant scope yields a fresh draft.
final inventoryReorderDraftProvider =
    StateNotifierProvider.autoDispose<
      InventoryReorderController,
      InventoryReorderDraft
    >((ref) {
      ref.watch(tenantIdProvider);
      ref.watch(appIdProvider);
      return InventoryReorderController();
    });

class InventoryReorderController extends StateNotifier<InventoryReorderDraft> {
  InventoryReorderController() : super(const InventoryReorderDraft());

  void setQuantity(InventoryItem item, int quantity) {
    if (quantity < 0) throw ArgumentError.value(quantity, 'quantity');
    final updated = Map<String, InventoryReorderLine>.of(state.lines);
    if (quantity == 0) {
      updated.remove(item.id);
    } else {
      updated[item.id] = InventoryReorderLine.fromItem(item, quantity);
    }
    state = InventoryReorderDraft(
      lines: Map.unmodifiable(updated),
      note: state.note,
    );
  }

  void setNote(String value) =>
      state = InventoryReorderDraft(lines: state.lines, note: value);

  void clear() => state = const InventoryReorderDraft();
}
