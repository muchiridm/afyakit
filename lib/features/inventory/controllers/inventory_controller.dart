import 'package:afyakit/features/import/import_inventory_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/features/inventory/models/items/medication_item.dart';
import 'package:afyakit/features/inventory/models/items/consumable_item.dart';
import 'package:afyakit/features/inventory/models/items/equipment_item.dart';
import 'package:afyakit/features/inventory/models/item_type_enum.dart';
import 'package:afyakit/features/inventory/services/inventory_service.dart';
import 'package:afyakit/features/batches/services/batch_service.dart';
import 'package:afyakit/shared/providers/api_route_provider.dart';
import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:afyakit/hq/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/services/dialog_service.dart';
import 'package:afyakit/main.dart';

final inventoryControllerProvider =
    StateNotifierProvider<InventoryController, void>((ref) {
      final routes = ref.watch(apiRouteProvider);
      final token = ref.watch(tokenProvider);
      return InventoryController(ref, InventoryService(routes, token));
    });

class InventoryController extends StateNotifier<void> {
  final Ref ref;
  final InventoryService _api;

  InventoryController(this.ref, this._api) : super(null);

  Future<void> create(BaseInventoryItem item, ItemType type) async {
    try {
      await _handleCreate(item, type);
      SnackService.showSuccess(
        '✅ ${type.name.capitalize()} created successfully.',
      );
    } catch (e) {
      SnackService.showError('❌ Failed to create ${type.name}:\n$e');
    }
  }

  Future<void> update(BaseInventoryItem item, ItemType type) async {
    try {
      await _handleUpdate(item, type);
      SnackService.showSuccess('✅ ${type.name.capitalize()} updated.');
    } catch (e) {
      SnackService.showError('❌ Failed to update ${type.name}:\n$e');
    }
  }

  Future<void> delete(String id, ItemType type) async {
    final tenantId = ref.read(tenantIdProvider);

    try {
      final linked = await BatchService.hasLinkedBatches(
        tenantId: tenantId,
        itemId: id,
        itemType: type,
      );

      if (linked) {
        SnackService.showError(
          '❌ Cannot delete this ${type.name}. It has linked batch records.',
        );
        return;
      }

      final confirmed = await DialogService.confirm(
        title: 'Permanently Delete Item?',
        content: 'This action cannot be undone. Are you sure?',
        confirmText: 'Delete',
        confirmColor: Colors.redAccent,
      );

      if (confirmed != true) return;

      await _handleDelete(id, type);

      SnackService.showSuccess(
        '✅ ${type.name.capitalize()} deleted successfully.',
      );
      navigatorKey.currentState?.maybePop();
    } catch (e) {
      SnackService.showError('❌ Failed to delete ${type.name}:\n$e');
    }
  }

  Future<Map<String, dynamic>> updateFields({
    required String itemId,
    required ItemType type,
    required Map<String, dynamic> fields,
  }) async {
    debugPrint('📤 Sending updateFields() to backend: [$itemId] $fields');

    try {
      final result = await switch (type) {
        ItemType.medication => _api.updateMedicationFields(itemId, fields),
        ItemType.consumable => _api.updateConsumableFields(itemId, fields),
        ItemType.equipment => _api.updateEquipmentFields(itemId, fields),
        ItemType.unknown => throw ArgumentError('Unsupported type: unknown'),
      };

      SnackService.showSuccess('✅ ${type.name.capitalize()} updated.');
      return result; // ✅ Return backend data
    } catch (e) {
      SnackService.showError('❌ Failed to update ${type.name}:\n$e');
      rethrow;
    }
  }

  // ────────────────────────────────────────────────────────────────
  // 🧱 Internal Helpers
  // ────────────────────────────────────────────────────────────────

  Future<void> _handleCreate(BaseInventoryItem item, ItemType type) {
    return switch (type) {
      ItemType.medication => _api.createMedication(item as MedicationItem),
      ItemType.consumable => _api.createConsumable(item as ConsumableItem),
      ItemType.equipment => _api.createEquipment(item as EquipmentItem),
      ItemType.unknown => throw ArgumentError('Unsupported type: unknown'),
    };
  }

  Future<void> _handleUpdate(BaseInventoryItem item, ItemType type) {
    return switch (type) {
      ItemType.medication => _api.updateMedication(item as MedicationItem),
      ItemType.consumable => _api.updateConsumable(item as ConsumableItem),
      ItemType.equipment => _api.updateEquipment(item as EquipmentItem),
      ItemType.unknown => throw ArgumentError('Unsupported type: unknown'),
    };
  }

  Future<void> _handleDelete(String id, ItemType type) {
    return switch (type) {
      ItemType.medication => _api.deleteMedication(id),
      ItemType.consumable => _api.deleteConsumable(id),
      ItemType.equipment => _api.deleteEquipment(id),
      ItemType.unknown => throw ArgumentError('Unsupported type: unknown'),
    };
  }
}
