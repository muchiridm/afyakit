// lib/core/catalog/catalog_service.dart

import 'dart:convert';
import 'package:dio/dio.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes.dart';

import 'catalog_models.dart';

class CatalogService {
  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  CatalogService({required this.api, required this.routes});

  /// Returns (items, hasMore)
  ///
  /// Uses AfyaKit BE as the only gateway.
  /// BE proxies DawaIndex.
  Future<(List<CatalogTile>, bool)> fetchTiles({
    required int offset,
    required int limit,
    CatalogQuery query = const CatalogQuery(),
  }) async {
    final Dio dio = api.dio;

    final uri = routes.diSalesTiles(
      q: query.q.trim().isNotEmpty ? query.q.trim() : null,
      form: query.form.isNotEmpty ? query.form : null,
      limit: limit,
      offset: offset,
    );

    final res = await dio.getUri(uri);

    final Map<String, Object?> body = switch (res.data) {
      final Map<String, Object?> m => m,
      final String s => jsonDecode(s) as Map<String, Object?>,
      _ => throw StateError('Unexpected tiles payload'),
    };

    // Expected BE response: { items, total, offset, nextOffset }
    final items = (body['items'] as List)
        .cast<Map<String, Object?>>()
        .map(CatalogTile.fromJson)
        .toList();

    final nextOffset = body['nextOffset'] as int?;
    final hasMore = (nextOffset != null) && items.isNotEmpty;

    return (items, hasMore);
  }
}
