// lib/core/catalog/catalog_service.dart

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:afyakit/core/api/dawaindex/client.dart';

import 'catalog_models.dart';

class CatalogService {
  final DawaIndexClient api;
  CatalogService(this.api);

  /// Returns (items, nextOffsetExists)
  Future<(List<CatalogTile>, bool)> fetchTiles({
    required int offset,
    required int limit,
    CatalogQuery query = const CatalogQuery(),
  }) async {
    final res = await api.dio.get(
      '/v1/sales/tiles',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (query.q.trim().isNotEmpty) 'q': query.q.trim(),
        if (query.form.isNotEmpty) 'form': query.form,
        // 'sort' reserved for future support
      },
      options: Options(extra: {'skipAuth': true}), // public endpoint
    );

    final Map<String, Object?> body = switch (res.data) {
      final Map<String, Object?> m => m,
      final String s => jsonDecode(s) as Map<String, Object?>,
      _ => throw StateError('Unexpected tiles payload'),
    };

    final items = (body['items'] as List)
        .cast<Map<String, Object?>>()
        .map(CatalogTile.fromJson)
        .toList();

    final nextOffset = body['next_offset'] as int?;
    final hasMore = (nextOffset != null) && items.isNotEmpty;

    return (items, hasMore);
  }
}
