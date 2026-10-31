import 'package:dio/dio.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';

import 'inventory_batch.dart';

/// Inventory batches are API-owned.
/// No direct Firestore client writes.
class InventoryBatchesService {
  const InventoryBatchesService({
    required this.dio,
    required this.routes,
    required this.appId,
  });

  final Dio dio;
  final AfyaKitRoutes routes;
  final String appId;

  Uri get _base {
    final items = routes.items();
    final segments = items.pathSegments.where((s) => s.isNotEmpty).toList();

    if (segments.isEmpty || segments.last != 'items') {
      throw StateError('Unexpected inventory route: $items');
    }

    segments[segments.length - 1] = 'batches';

    return items.replace(pathSegments: segments, query: null);
  }

  Options get _options => Options(headers: {'x-app-id': appId});

  Uri _at(String id) => _base.replace(
    pathSegments: [..._base.pathSegments.where((s) => s.isNotEmpty), id],
  );

  Uri _restore(String id) => _base.replace(
    pathSegments: [
      ..._base.pathSegments.where((s) => s.isNotEmpty),
      id,
      'restore',
    ],
  );

  Map<String, dynamic> _object(dynamic data) {
    if (data is! Map) {
      throw const FormatException('Expected JSON object');
    }

    return Map<String, dynamic>.from(data);
  }

  InventoryBatch _batch(dynamic data) =>
      InventoryBatch.fromJson(_object(_object(data)['batch']));

  /// Lists batches within the current app.
  Future<InventoryBatchPage> list({
    String? itemId,
    String? storeId,
    String? itemType,
    bool includeArchived = false,
    int page = 1,
    int perPage = 100,
  }) async {
    final uri = _base.replace(
      queryParameters: {
        if (itemId?.isNotEmpty == true) 'item_id': itemId!,
        if (storeId?.isNotEmpty == true) 'store_id': storeId!,
        if (itemType?.isNotEmpty == true) 'item_type': itemType!,
        'include_archived': '$includeArchived',
        'page': '$page',
        'per_page': '$perPage',
      },
    );

    final response = await dio.getUri(uri, options: _options);

    final json = _object(response.data);

    return InventoryBatchPage(
      batches: (json['batches'] as List? ?? const [])
          .map((v) => InventoryBatch.fromJson(_object(v)))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? page,
      hasMore: json['has_more'] == true,
    );
  }

  /// Retrieves all pages of batches.
  Future<List<InventoryBatch>> listAll({
    String? itemId,
    String? storeId,
    String? itemType,
    bool includeArchived = false,
  }) async {
    final result = <InventoryBatch>[];

    for (var page = 1; ; page++) {
      final part = await list(
        itemId: itemId,
        storeId: storeId,
        itemType: itemType,
        includeArchived: includeArchived,
        page: page,
      );

      result.addAll(part.batches);

      if (!part.hasMore) return result;
    }
  }

  /// Retrieves a single batch.
  Future<InventoryBatch> get(String id) async {
    final response = await dio.getUri(_at(id), options: _options);

    return _batch(response.data);
  }

  /// Creates a batch.
  ///
  /// Positive quantities require a valid open delivery session,
  /// supplied through InventoryBatchInput.deliveryId.
  Future<InventoryBatch> create(InventoryBatchInput input) async {
    final response = await dio.postUri(
      _base,
      data: input.toJson(),
      options: _options,
    );

    return _batch(response.data);
  }

  /// Updates permitted batch metadata only.
  ///
  /// Quantity, item identity, location and delivery linkage
  /// cannot be modified through PATCH.
  Future<InventoryBatch> update(String id, Map<String, dynamic> patch) async {
    const forbidden = {
      'quantity',
      'item_id',
      'store_id',
      'item_type',
      'delivery_id',
    };

    if (patch.keys.any(forbidden.contains)) {
      throw ArgumentError(
        'Batch updates cannot change quantity, identity, '
        'location or delivery linkage.',
      );
    }

    final response = await dio.patchUri(
      _at(id),
      data: patch,
      options: _options,
    );

    return _batch(response.data);
  }

  /// Removes a batch according to backend inventory rules.
  ///
  /// - Open delivery: cancels the draft batch for its owner.
  /// - Empty batch: archives the batch.
  /// - Finalized batch with stock: requires a stock movement first.
  ///
  /// Ownership and stock restrictions are enforced by the backend.
  Future<void> remove(String id) async {
    await dio.deleteUri(_at(id), options: _options);
  }

  /// Restores an archived batch, subject to backend validation.
  Future<InventoryBatch> restore(String id) async {
    final response = await dio.postUri(_restore(id), options: _options);

    return _batch(response.data);
  }
}
