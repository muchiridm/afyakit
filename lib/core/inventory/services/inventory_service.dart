import 'dart:convert';
import 'package:afyakit/core/inventory/extensions/item_type_x.dart';
import 'package:afyakit/core/inventory/models/items/base_inventory_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:afyakit/api/api_routes.dart';
import 'package:afyakit/core/auth_users/providers/auth_session/token_provider.dart';
import 'package:afyakit/shared/utils/payload_sanitizer.dart';

import '../models/items/medication_item.dart';
import '../models/items/consumable_item.dart';
import '../models/items/equipment_item.dart';

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  final token = ref.read(tokenProvider);
  final routes = ref.read(apiRouteProvider);
  return InventoryService(routes, token);
});

class InventoryService {
  final ApiRoutes routes;
  final TokenProvider tokenProvider;

  InventoryService(this.routes, this.tokenProvider);

  // ─────────────────────────────────────
  // 🔍 READ

  Future<BaseInventoryItem> getItemById(String id, ItemType type) async {
    final url = routes.itemById(id);
    final res = await _get(url);
    final map = jsonDecode(res.body);

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
    final url = routes.createItem();
    data.remove('id'); // Don’t send frontend ID
    final payload = {...PayloadSanitizer.sanitize(data), 'itemType': itemType};

    final res = await _post(url, body: jsonEncode(payload));
    if (!_ok(res.statusCode, expect: {201})) {
      throw Exception("Failed to create $itemType: ${res.body}");
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
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

    final url = routes.itemById(id);
    final payload = {...PayloadSanitizer.sanitize(data), 'itemType': itemType};

    debugPrint('📡 PUT $url');
    debugPrint('📦 Payload: ${jsonEncode(payload)}');

    final res = await _put(url, body: jsonEncode(payload));

    debugPrint('🔁 Response: ${res.statusCode} — ${res.body}');

    if (!_ok(res.statusCode)) {
      throw Exception("Failed to update $itemType [$id]: ${res.body}");
    }
  }

  Future<Map<String, dynamic>> updateMedicationFields(
    String id,
    Map<String, dynamic> fields,
  ) {
    final url = routes.itemById(id);
    return _patchJson(url, fields);
  }

  Future<Map<String, dynamic>> updateConsumableFields(
    String id,
    Map<String, dynamic> fields,
  ) {
    final url = routes.itemById(id);
    return _patchJson(url, fields);
  }

  Future<Map<String, dynamic>> updateEquipmentFields(
    String id,
    Map<String, dynamic> fields,
  ) {
    final url = routes.itemById(id);
    return _patchJson(url, fields);
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
    // Send as query param (some servers ignore DELETE bodies)
    final url = base.replace(
      queryParameters: {...base.queryParameters, 'itemType': typeKey},
    );

    // Also send JSON body for servers that accept it
    final res = await _delete(url, body: jsonEncode({'itemType': typeKey}));

    debugPrint('🗑️ DELETE $url');
    debugPrint('🔁 Response: ${res.statusCode} — ${res.body}');

    if (!_ok(res.statusCode)) {
      throw Exception("Failed to delete $typeKey [$itemId]: ${res.body}");
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
  // 🔧 HTTP HELPERS

  Future<http.Response> _get(Uri url) async {
    final token = await tokenProvider.getToken();
    return http.get(url, headers: _headers(token));
  }

  Future<http.Response> _post(Uri url, {required String body}) async {
    final token = await tokenProvider.getToken();
    return http.post(url, headers: _headers(token), body: body);
  }

  Future<http.Response> _put(Uri url, {required String body}) async {
    final token = await tokenProvider.getToken();
    return http.put(url, headers: _headers(token), body: body);
  }

  Future<http.Response> _patch(Uri url, {required String body}) async {
    final token = await tokenProvider.getToken();
    return http.patch(url, headers: _headers(token), body: body);
  }

  Future<http.Response> _delete(Uri url, {String? body}) async {
    final token = await tokenProvider.getToken();
    return http.delete(url, headers: _headers(token), body: body);
  }

  Map<String, String> _headers(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'x-tenant-id': routes.tenantId,
    };
  }

  bool _ok(int status, {Set<int>? expect}) {
    if (expect != null) return expect.contains(status);
    // Accept any 2xx (many APIs return 204 for DELETE)
    return status >= 200 && status < 300;
  }

  Future<Map<String, dynamic>> _patchJson(
    Uri url,
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
      final res = await _patch(url, body: jsonEncode(payload));
      debugPrint('📤 PATCH Payload: $payload');
      debugPrint('🔁 Response: ${res.statusCode} — ${res.body}');

      if (!_ok(res.statusCode)) {
        throw Exception("Failed to update item: ${res.body}");
      }

      return (res.body.isEmpty)
          ? {}
          : (jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e, stack) {
      debugPrint('🔥 PATCH exception: $e\n$stack');
      rethrow;
    }
  }
}
