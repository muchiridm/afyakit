// lib/core/inventory/inventory_service.dart

import 'dart:convert';

import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes.dart';

import 'package:afyakit/modules/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/modules/inventory/items/models/items/base_inventory_item.dart';
import 'package:afyakit/shared/utils/payload_sanitizer.dart';

import '../models/items/medication_item.dart';
import '../models/items/consumable_item.dart';
import '../models/items/equipment_item.dart';

/// Provider (awaits AfyaKit client so Dio is ready)
final inventoryServiceProvider = FutureProvider<InventoryService>((ref) async {
  final tenantId = ref.watch(tenantSlugProvider);
  final client = await ref.watch(afyakitClientProvider.future);
  final routes = AfyaKitRoutes(tenantId);
  return InventoryService(routes: routes, dio: client.dio);
});

class InventoryService {
  final AfyaKitRoutes routes;
  final Dio dio;

  InventoryService({required this.routes, required this.dio});

  // ─────────────────────────────────────
  // 🔍 READ

  Future<BaseInventoryItem> getItemById(String id, ItemType type) async {
    final uri = routes.itemById(id);
    final res = await dio.getUri(uri);

    // Dio may already parse JSON, ensure Map
    final map = switch (res.data) {
      final Map<String, dynamic> m => m,
      final String s => jsonDecode(s) as Map<String, dynamic>,
      _ => throw StateError('Unexpected payload for GET $uri'),
    };

    return switch (type) {
      ItemType.medication => MedicationItem.fromMap(id, map),
      ItemType.consumable => ConsumableItem.fromMap(id, map),
      ItemType.equipment => EquipmentItem.fromMap(id, map),
      ItemType.unknown => throw Exception(
        '❌ Cannot load item with unknown type',
      ),
    };
  }

  // ─────────────────────────────────────
  // ➕ CREATE

  Future<MedicationItem> createMedication(MedicationItem item) async {
    final res = await _createItem('medication', item.toMap());
    return MedicationItem.fromMap(res['id'], res);
  }

  Future<ConsumableItem> createConsumable(ConsumableItem item) async {
    final res = await _createItem('consumable', item.toMap());
    return ConsumableItem.fromMap(res['id'], res);
  }

  Future<EquipmentItem> createEquipment(EquipmentItem item) async {
    final res = await _createItem('equipment', item.toMap());
    return EquipmentItem.fromMap(res['id'], res);
  }

  Future<Map<String, dynamic>> _createItem(
    String itemType,
    Map<String, dynamic> data,
  ) async {
    final uri = routes.createItem();
    data.remove('id'); // Don’t send frontend ID
    final payload = {...PayloadSanitizer.sanitize(data), 'itemType': itemType};

    final res = await dio.postUri(
      uri,
      data: payload,
      options: Options(
        // keep optional header if your BE uses it (usually redundant)
        headers: {'x-tenant-id': routes.tenantId},
      ),
    );

    if (!_ok(res.statusCode ?? 0, expect: {201})) {
      throw Exception("Failed to create $itemType: ${res.data}");
    }

    return switch (res.data) {
      final Map<String, dynamic> m => m,
      final String s => jsonDecode(s) as Map<String, dynamic>,
      _ => throw StateError('Unexpected payload for POST $uri'),
    };
  }

  // ─────────────────────────────────────
  // ✏️ UPDATE

  Future<void> updateMedication(MedicationItem item) =>
      _updateItem(item.id, 'medication', item.toMap());

  Future<void> updateConsumable(ConsumableItem item) =>
      _updateItem(item.id, 'consumable', item.toMap());

  Future<void> updateEquipment(EquipmentItem item) =>
      _updateItem(item.id, 'equipment', item.toMap());

  Future<void> _updateItem(
    String? id,
    String itemType,
    Map<String, dynamic> data,
  ) async {
    if (id == null || id.isEmpty) {
      throw Exception('ID is required for update');
    }

    final uri = routes.itemById(id);
    final payload = {...PayloadSanitizer.sanitize(data), 'itemType': itemType};

    debugPrint('📡 PUT $uri');
    debugPrint('📦 Payload: ${jsonEncode(payload)}');

    final res = await dio.putUri(
      uri,
      data: payload,
      options: Options(headers: {'x-tenant-id': routes.tenantId}),
    );

    debugPrint('🔁 Response: ${res.statusCode} — ${res.data}');

    if (!_ok(res.statusCode ?? 0)) {
      throw Exception("Failed to update $itemType [$id]: ${res.data}");
    }
  }

  Future<Map<String, dynamic>> updateMedicationFields(
    String id,
    Map<String, dynamic> fields,
  ) {
    final uri = routes.itemById(id);
    return _patchJson(uri, fields);
  }

  Future<Map<String, dynamic>> updateConsumableFields(
    String id,
    Map<String, dynamic> fields,
  ) {
    final uri = routes.itemById(id);
    return _patchJson(uri, fields);
  }

  Future<Map<String, dynamic>> updateEquipmentFields(
    String id,
    Map<String, dynamic> fields,
  ) {
    final uri = routes.itemById(id);
    return _patchJson(uri, fields);
  }

  // ─────────────────────────────────────
  // ❌ DELETE  (send itemType)

  Future<void> deleteMedication(String id) =>
      deleteItem(itemId: id, type: ItemType.medication);

  Future<void> deleteConsumable(String id) =>
      deleteItem(itemId: id, type: ItemType.consumable);

  Future<void> deleteEquipment(String id) =>
      deleteItem(itemId: id, type: ItemType.equipment);

  /// Generic delete by id + type (preferred).
  Future<void> deleteItem({
    required String itemId,
    required ItemType type,
  }) async {
    final typeKey = type.key; // "medication" | "consumable" | "equipment"

    final base = routes.itemById(itemId);
    final uri = base.replace(
      queryParameters: {...base.queryParameters, 'itemType': typeKey},
    );

    // Send both query param and JSON body (some servers ignore DELETE bodies)
    final res = await dio.deleteUri(
      uri,
      data: {'itemType': typeKey},
      options: Options(headers: {'x-tenant-id': routes.tenantId}),
    );

    debugPrint('🗑️ DELETE $uri');
    debugPrint('🔁 Response: ${res.statusCode} — ${res.data}');

    if (!_ok(res.statusCode ?? 0)) {
      throw Exception("Failed to delete $typeKey [$itemId]: ${res.data}");
    }
  }

  /// Convenience: delete using the runtime model.
  Future<void> deleteItemByModel(BaseInventoryItem item) {
    final id = (item.id ?? '').trim();
    if (id.isEmpty) {
      throw Exception('missing-itemId');
    }
    final t = item.type == ItemType.unknown
        ? ItemTypeX.inferFromModel(item)
        : item.type;
    if (t == ItemType.unknown) {
      throw Exception('missing-or-invalid-itemType');
    }
    return deleteItem(itemId: id, type: t);
  }

  // ─────────────────────────────────────
  // 🔧 INTERNAL HELPERS

  bool _ok(int status, {Set<int>? expect}) {
    if (expect != null) return expect.contains(status);
    return status >= 200 && status < 300; // accept any 2xx
  }

  Future<Map<String, dynamic>> _patchJson(
    Uri uri,
    Map<String, dynamic> data,
  ) async {
    debugPrint('🟡 patchJson() called with data: $data');

    final payload = PayloadSanitizer.sanitize(data);
    debugPrint('🟡 Sanitized payload: $payload');

    if (payload.isEmpty) {
      debugPrint('⚠️ Skipping PATCH — empty payload');
      return {};
    }

    try {
      final res = await dio.patchUri(
        uri,
        data: payload,
        options: Options(headers: {'x-tenant-id': routes.tenantId}),
      );
      debugPrint('📤 PATCH Payload: $payload');
      debugPrint('🔁 Response: ${res.statusCode} — ${res.data}');

      if (!_ok(res.statusCode ?? 0)) {
        throw Exception("Failed to update item: ${res.data}");
      }

      return switch (res.data) {
        final Map<String, dynamic> m => m,
        final String s => jsonDecode(s) as Map<String, dynamic>,
        _ => <String, dynamic>{},
      };
    } catch (e, stack) {
      debugPrint('🔥 PATCH exception: $e\n$stack');
      rethrow;
    }
  }
}
