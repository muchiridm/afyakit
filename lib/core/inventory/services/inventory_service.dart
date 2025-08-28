import 'dart:convert';
import 'package:afyakit/core/inventory/models/item_type_enum.dart';
import 'package:afyakit/core/inventory/models/items/base_inventory_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:afyakit/api/api_routes.dart';
import 'package:afyakit/shared/providers/token_provider.dart';
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
    if (res.statusCode != 201) {
      throw Exception("Failed to create $itemType: ${res.body}");
    }

    return jsonDecode(res.body);
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

    if (res.statusCode != 200) {
      throw Exception("Failed to update $itemType [$id]: ${res.body}");
    }
  }

  Future<Map<String, dynamic>> updateMedicationFields(
    String id,
    Map<String, dynamic> fields,
  ) {
    final url = routes.itemById(id);
    return _patchJson(url, fields); // ✅ return the backend response
  }

  /// Updates SKU fields.
  /// Returns the updated item data from the backend.

  Future<Map<String, dynamic>> updateConsumableFields(
    String id,
    Map<String, dynamic> fields,
  ) {
    final url = routes.itemById(id);
    return _patchJson(url, fields); // ✅ return the backend response
  }

  Future<Map<String, dynamic>> updateEquipmentFields(
    String id,
    Map<String, dynamic> fields,
  ) {
    final url = routes.itemById(id);
    return _patchJson(url, fields); // ✅ return the backend response
  }

  // ─────────────────────────────────────
  // ❌ DELETE

  Future<void> deleteMedication(String id) => _deleteItem(id, 'medication');
  Future<void> deleteConsumable(String id) => _deleteItem(id, 'consumable');
  Future<void> deleteEquipment(String id) => _deleteItem(id, 'equipment');

  Future<void> _deleteItem(String id, String itemType) async {
    final url = routes.itemById(id);
    final res = await _delete(url);
    if (res.statusCode != 200) {
      throw Exception("Failed to delete $itemType [$id]: ${res.body}");
    }
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

  Future<http.Response> _delete(Uri url) async {
    final token = await tokenProvider.getToken();
    return http.delete(url, headers: _headers(token));
  }

  Map<String, String> _headers(String token) {
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'x-tenant-id': routes.tenantId,
    };
    return headers;
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
      return {}; // ✅ Return empty map instead of void
    }

    try {
      final res = await _patch(url, body: jsonEncode(payload));
      debugPrint('📤 PATCH Payload: $payload');
      debugPrint('🔁 Response: ${res.statusCode} — ${res.body}');

      if (res.statusCode != 200) {
        throw Exception("Failed to update item: ${res.body}");
      }

      return jsonDecode(res.body)
          as Map<String, dynamic>; // ✅ Return parsed backend response
    } catch (e, stack) {
      debugPrint('🔥 PATCH exception: $e\n$stack');
      rethrow;
    }
  }

  Future<http.Response> _patch(Uri url, {required String body}) async {
    final token = await tokenProvider.getToken();
    return http.patch(url, headers: _headers(token), body: body);
  }
}
