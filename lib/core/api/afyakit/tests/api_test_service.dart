// lib/core/api/afyakit/tests/api_test_service.dart

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:afyakit/core/api/afyakit/client.dart';

class ApiTestService {
  ApiTestService(this._client);

  final AfyaKitClient _client;

  Dio get _dio => _client.dio;

  String prettyJson(Object? data) {
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  // ─────────────────────────────────────────────
  // Connectivity
  // ─────────────────────────────────────────────

  Future<Response<dynamic>> ping() => _dio.get('/ping');

  // ─────────────────────────────────────────────
  // Inventory items
  // ─────────────────────────────────────────────

  Future<Response<dynamic>> getItemById(String itemId) =>
      _dio.get('/inventory/items/${Uri.encodeComponent(itemId.trim())}');

  Future<Response<dynamic>> listItems({
    String? itemType,
    int page = 1,
    int perPage = 50,
  }) => _dio.get(
    '/inventory/items',
    queryParameters: {
      if (itemType != null && itemType.trim().isNotEmpty)
        'item_type': itemType.trim(),
      'page': page,
      'per_page': perPage,
    },
  );

  Future<Response<dynamic>> listItemTypes() =>
      _dio.get('/inventory/items/types');

  // ─────────────────────────────────────────────
  // Inventory locations
  // ─────────────────────────────────────────────

  Future<Response<dynamic>> listLocations({String? locationType}) => _dio.get(
    '/inventory/locations',
    queryParameters: {
      if (locationType != null && locationType.trim().isNotEmpty)
        'location_type': locationType.trim(),
    },
  );

  // ─────────────────────────────────────────────
  // Inventory batches
  // ─────────────────────────────────────────────

  Future<Response<dynamic>> getBatchById(String batchId) =>
      _dio.get('/inventory/batches/${Uri.encodeComponent(batchId.trim())}');

  Future<Response<dynamic>> listBatches({
    String? storeId,
    int page = 1,
    int perPage = 50,
  }) => _dio.get(
    '/inventory/batches',
    queryParameters: {
      if (storeId != null && storeId.trim().isNotEmpty)
        'store_id': storeId.trim(),
      'page': page,
      'per_page': perPage,
    },
  );
}
