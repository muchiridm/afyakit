import 'package:afyakit/modules/inventory/items/providers/item_stream_providers.dart';
import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:collection/collection.dart';
import 'package:afyakit/modules/inventory/items/controllers/inventory_editable_base.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/modules/inventory/items/controllers/inventory_controller.dart';
import 'package:afyakit/modules/inventory/items/models/items/medication_item.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/modules/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/modules/inventory/items/utils/item_validator.dart';

final medicationControllerProvider = Provider<MedicationController>((ref) {
  return MedicationController(ref);
});

class MedicationController extends InventoryEditableBase {
  final Ref _ref;

  MedicationController(this._ref);

  InventoryController get _inventory =>
      _ref.read(inventoryControllerProvider.notifier);

  List<MedicationItem> get all {
    final tenantId = _ref.read(tenantSlugProvider);
    final asyncValue = _ref.watch(medicationItemsStreamProvider(tenantId));
    return asyncValue.maybeWhen(data: (items) => items, orElse: () => []);
  }

  List<String> validate(MedicationItem item) {
    final validator = _ref.read(itemValidatorProvider);
    return validator.validate(ItemType.medication, item.toMap());
  }

  Future<void> create(MedicationItem item) async {
    final errors = validate(item);
    if (errors.isNotEmpty) {
      SnackService.showError(errors.join('\n'));
      return;
    }

    await _inventory.create(item, ItemType.medication);
    SnackService.showSuccess('✅ Medication added!');
  }

  Future<void> update(MedicationItem item) async {
    final errors = validate(item);
    if (errors.isNotEmpty) {
      SnackService.showError(errors.join('\n'));
      return;
    }

    await _inventory.update(item, ItemType.medication);
    SnackService.showSuccess('✅ Medication updated!');
  }

  Future<void> delete(String id) async {
    await _inventory.delete(id, ItemType.medication);
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
}
