import 'dart:convert';
import 'package:afyakit/core/inventory/extensions/item_type_x.dart';
import 'package:dio/dio.dart';
import 'package:afyakit/api/api_client.dart';

/// A *minimal* shape used for search results (strictly typed; no `any`)
class InventoryItemLite {
  final String id; // internal UUID
  final String? docId; // backend doc id if returned
  final String? genericName;
  final String? brandName;
  final String? description;
  final String? itemType; // string from API (still useful to log)

  const InventoryItemLite({
    required this.id,
    this.docId,
    this.genericName,
    this.brandName,
    this.description,
    this.itemType,
  });

  factory InventoryItemLite.fromJson(Map<String, Object?> json) {
    String asString(Object? v) => v?.toString() ?? '';
    return InventoryItemLite(
      id: asString(json['id']),
      docId: json['docId']?.toString(),
      genericName: json['genericName']?.toString(),
      brandName: json['brandName']?.toString(),
      description: json['description']?.toString(),
      itemType: json['itemType']?.toString(),
    );
  }
}

class ApiTestService {
  final ApiClient _client;
  ApiTestService(this._client);

  Dio get _dio => _client.dio;

  // ---------- Utils ----------
  String prettyJson(Object? data) =>
      const JsonEncoder.withIndent('  ').convert(data);

  // ---------- Simple pings ----------
  Future<Response<dynamic>> ping() => _dio.get('/ping');

  // ---------- Inventory ----------
  Future<Response<dynamic>> getItemById(String itemId) =>
      _dio.get('/inventory/$itemId');

  Future<List<InventoryItemLite>> listInventory(ItemType type) async {
    assert(type.isConcrete, 'ItemType.unknown is not listable');
    final res = await _dio.get(
      '/inventory',
      queryParameters: {'type': type.apiName},
    );
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map<String, Object?>>()
          .map(InventoryItemLite.fromJson)
          .toList();
    }
    return const <InventoryItemLite>[];
  }

  /// Search for an item across {medication, consumable, equipment} by either
  /// internal `id` or backend `docId`.
  Future<({ItemType? type, InventoryItemLite? item})> searchItemById(
    String target,
  ) async {
    for (final t in ItemTypeX.searchable) {
      final items = await listInventory(t);
      for (final it in items) {
        if (it.id == target || (it.docId != null && it.docId == target)) {
          return (type: t, item: it);
        }
      }
    }
    return (type: null, item: null);
  }

  // ---------- Stores / Batches ----------
  Future<List<String>> listStores() async {
    // Expect API returns e.g. [{id:"store_001", name:"Main Store"}, ...]
    final res = await _dio.get('/stores');
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map<String, Object?>>()
          .map((e) => e['id']?.toString())
          .whereType<String>()
          .toList();
    }
    return const <String>[];
  }

  Future<Response<dynamic>> getBatch(String storeId, String batchId) =>
      _dio.get('/stores/$storeId/batches/$batchId');

  /// Try a direct `/batches/{batchId}` if available, then fan-out by store.
  Future<({String? storeId, Map<String, Object?>? batchJson})>
  searchBatchAcrossStores(String batchId, {bool tryDirectFirst = true}) async {
    if (tryDirectFirst) {
      try {
        final direct = await _dio.get('/batches/$batchId');
        final data = direct.data;
        if (data is Map<String, Object?>) {
          final storeId = data['storeId']?.toString(); // if API includes it
          return (storeId: storeId, batchJson: data);
        }
      } catch (_) {
        // ignore and fallback to per-store probing
      }
    }

    final stores = await listStores();
    for (final s in stores) {
      try {
        final res = await getBatch(s, batchId);
        final data = res.data;
        if (data is Map<String, Object?>) {
          return (storeId: s, batchJson: data);
        }
      } catch (_) {
        // 404s expected → keep probing
      }
    }
    return (storeId: null, batchJson: null);
  }
}
