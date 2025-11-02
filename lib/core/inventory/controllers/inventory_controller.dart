// lib/core/inventory/controllers/inventory_controller.dart

import 'package:afyakit/api/afyakit/providers.dart'; // afyakitClientProvider
import 'package:afyakit/api/afyakit/routes.dart';
import 'package:afyakit/app/afyakit_app.dart';
import 'package:afyakit/hq/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/shared/utils/normalize/normalize_string.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/services/dialog_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/core/inventory/models/items/medication_item.dart';
import 'package:afyakit/core/inventory/models/items/consumable_item.dart';
import 'package:afyakit/core/inventory/models/items/equipment_item.dart';
import 'package:afyakit/core/inventory/extensions/item_type_x.dart';
import 'package:afyakit/core/inventory/services/inventory_service.dart';
import 'package:afyakit/core/batches/services/batch_service.dart';

final inventoryControllerProvider =
    StateNotifierProvider<InventoryController, void>((ref) {
      // Build the controller; it will lazily construct the service inside.
      return InventoryController(ref);
    });

class InventoryController extends StateNotifier<void> {
  final Ref ref;

  // Lazily-built service (await this wherever you need API calls)
  late final Future<InventoryService> _api = _makeService();

  InventoryController(this.ref) : super(null);

  Future<InventoryService> _makeService() async {
    final tenantId = ref.read(tenantIdProvider);
    final client = await ref.read(
      afyakitClientProvider.future,
    ); // await Dio client
    final routes = AfyaKitRoutes(tenantId);
    return InventoryService(routes: routes, dio: client.dio);
  }

  // ────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ────────────────────────────────────────────────────────────────

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
      final api = await _api;
      final result = await switch (type) {
        ItemType.medication => api.updateMedicationFields(itemId, fields),
        ItemType.consumable => api.updateConsumableFields(itemId, fields),
        ItemType.equipment => api.updateEquipmentFields(itemId, fields),
        ItemType.unknown => throw ArgumentError('Unsupported type: unknown'),
      };

      SnackService.showSuccess('✅ ${type.name.capitalize()} updated.');
      return result; // pass backend data through
    } catch (e) {
      SnackService.showError('❌ Failed to update ${type.name}:\n$e');
      rethrow;
    }
  }

  // ────────────────────────────────────────────────────────────────
  // Internal helpers
  // ────────────────────────────────────────────────────────────────

  Future<Future<BaseInventoryItem>> _handleCreate(
    BaseInventoryItem item,
    ItemType type,
  ) async {
    final api = await _api;
    return switch (type) {
      ItemType.medication => api.createMedication(item as MedicationItem),
      ItemType.consumable => api.createConsumable(item as ConsumableItem),
      ItemType.equipment => api.createEquipment(item as EquipmentItem),
      ItemType.unknown => throw ArgumentError('Unsupported type: unknown'),
    };
  }

  Future<void> _handleUpdate(BaseInventoryItem item, ItemType type) async {
    final api = await _api;
    return switch (type) {
      ItemType.medication => api.updateMedication(item as MedicationItem),
      ItemType.consumable => api.updateConsumable(item as ConsumableItem),
      ItemType.equipment => api.updateEquipment(item as EquipmentItem),
      ItemType.unknown => throw ArgumentError('Unsupported type: unknown'),
    };
  }

  Future<void> _handleDelete(String id, ItemType type) async {
    final api = await _api;
    return switch (type) {
      ItemType.medication => api.deleteMedication(id),
      ItemType.consumable => api.deleteConsumable(id),
      ItemType.equipment => api.deleteEquipment(id),
      ItemType.unknown => throw ArgumentError('Unsupported type: unknown'),
    };
  }
}
