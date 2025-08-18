import 'package:afyakit/features/inventory/providers/item_streams/consumable_items_stream_provider.dart';
import 'package:afyakit/tenants/providers/tenant_id_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/inventory/models/items/consumable_item.dart';
import 'package:afyakit/shared/services/snack_service.dart';

import 'package:afyakit/features/inventory/controllers/inventory_controller.dart';
import 'package:afyakit/features/inventory/utils/item_validator.dart';
import 'package:afyakit/features/inventory/models/item_type_enum.dart';
import 'package:afyakit/features/inventory/controllers/inventory_editable_base.dart';
import 'package:collection/collection.dart';

final consumableControllerProvider = Provider<ConsumableController>((ref) {
  return ConsumableController(ref);
});

class ConsumableController extends InventoryEditableBase {
  final Ref _ref;

  ConsumableController(this._ref);

  InventoryController get _inventory =>
      _ref.read(inventoryControllerProvider.notifier);

  List<ConsumableItem> get all {
    final tenantId = _ref.read(tenantIdProvider);
    final asyncValue = _ref.watch(consumableItemsStreamProvider(tenantId));
    return asyncValue.maybeWhen(data: (items) => items, orElse: () => []);
  }

  List<String> validate(ConsumableItem item) {
    final validator = _ref.read(itemValidatorProvider);
    return validator.validate(ItemType.consumable, item.toMap());
  }

  Future<void> create(ConsumableItem item) async {
    final errors = validate(item);
    if (errors.isNotEmpty) {
      SnackService.showError(errors.join('\n'));
      return;
    }

    await _inventory.create(item, ItemType.consumable);
    SnackService.showSuccess('✅ Consumable added!');
  }

  Future<void> update(ConsumableItem item) async {
    final errors = validate(item);
    if (errors.isNotEmpty) {
      SnackService.showError(errors.join('\n'));
      return;
    }

    await _inventory.update(item, ItemType.consumable);
    SnackService.showSuccess('✅ Consumable updated!');
  }

  Future<void> delete(String id) async {
    await _inventory.delete(id, ItemType.consumable);
  }

  // ─────────────────────────────────────────────
  // ✅ InventoryEditableController Methods
  // ─────────────────────────────────────────────

  @override
  Future<void> setProposedOrder(String itemId, int value) async {
    final item = all.firstWhereOrNull((i) => i.id == itemId);
    if (item == null) return;
    await update(item.copyWith(proposedOrder: value));
  }

  @override
  Future<void> setReorderLevel(String itemId, int value) async {
    final item = all.firstWhereOrNull((i) => i.id == itemId);
    if (item == null) return;
    await update(item.copyWith(reorderLevel: value));
  }

  @override
  Future<void> setPackSize(String itemId, String value) async {
    final item = all.firstWhereOrNull((i) => i.id == itemId);
    if (item == null) return;
    await update(item.copyWith(packSize: value));
  }

  @override
  Future<void> setPackage(String itemId, String value) async {
    final item = all.firstWhereOrNull((i) => i.id == itemId);
    if (item == null) return;
    await update(item.copyWith(package: value));
  }
}
