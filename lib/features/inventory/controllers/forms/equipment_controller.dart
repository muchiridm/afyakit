import 'package:afyakit/features/inventory/providers/item_streams/equipment_items_stream_provider.dart';
import 'package:afyakit/hq/tenants/providers/tenant_id_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import 'package:afyakit/features/inventory/models/items/equipment_item.dart';
import 'package:afyakit/shared/services/snack_service.dart';

import 'package:afyakit/features/inventory/controllers/inventory_controller.dart';
import 'package:afyakit/features/inventory/utils/item_validator.dart';
import 'package:afyakit/features/inventory/models/item_type_enum.dart';
import 'package:afyakit/features/inventory/controllers/inventory_editable_base.dart';

final equipmentControllerProvider = Provider<EquipmentController>((ref) {
  return EquipmentController(ref);
});

class EquipmentController extends InventoryEditableBase {
  final Ref _ref;

  EquipmentController(this._ref);

  InventoryController get _inventory =>
      _ref.read(inventoryControllerProvider.notifier);

  List<EquipmentItem> get all {
    final tenantId = _ref.read(tenantIdProvider);
    final asyncValue = _ref.watch(equipmentItemsStreamProvider(tenantId));
    return asyncValue.maybeWhen(data: (items) => items, orElse: () => []);
  }

  List<String> validate(EquipmentItem item) {
    final validator = _ref.read(itemValidatorProvider);
    return validator.validate(ItemType.equipment, item.toMap());
  }

  Future<void> create(EquipmentItem item) async {
    final errors = validate(item);
    if (errors.isNotEmpty) {
      SnackService.showError(errors.join('\n'));
      return;
    }

    await _inventory.create(item, ItemType.equipment);
    SnackService.showSuccess('✅ Equipment added!');
  }

  Future<void> update(EquipmentItem item) async {
    final errors = validate(item);
    if (errors.isNotEmpty) {
      SnackService.showError(errors.join('\n'));
      return;
    }

    await _inventory.update(item, ItemType.equipment);
    SnackService.showSuccess('✅ Equipment updated!');
  }

  Future<void> delete(String id) async {
    await _inventory.delete(id, ItemType.equipment);
  }

  // ─────────────────────────────────────────────
  // ✅ InventoryEditableController Methods
  // ─────────────────────────────────────────────

  @override
  Future<void> setProposedOrder(String itemId, int value) async {
    final item = all.firstWhereOrNull((i) => i.id == itemId);
    if (item != null) {
      await update(item.copyWith(proposedOrder: value));
    }
  }

  @override
  Future<void> setReorderLevel(String itemId, int value) async {
    final item = all.firstWhereOrNull((i) => i.id == itemId);
    if (item != null) {
      await update(item.copyWith(reorderLevel: value));
    }
  }
}
