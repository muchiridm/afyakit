// lib/features/retail/catalog/services/catalog_service.dart

import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';

import '../models/catalog_models.dart';

class CatalogService {
  const CatalogService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  static Map<String, Object?> _asMap(Object? v) {
    if (v is Map<String, Object?>) return v;
    if (v is Map) return v.cast<String, Object?>();
    throw const FormatException('Expected object map');
  }

  static List<Map<String, Object?>> _asListOfMaps(Object? v) {
    if (v is List) {
      return v.map((e) => _asMap(e)).toList(growable: false);
    }
    return const [];
  }

  Future<(List<CatalogTile>, bool)> fetchTiles({
    required int offset,
    required int limit,
    CatalogQuery query = const CatalogQuery(),
  }) async {
    final Dio dio = api.dio;

    final Uri uri = routes.retailDiSalesTiles(
      q: query.q.trim().isNotEmpty ? query.q.trim() : null,
      form: query.form.trim().isNotEmpty ? query.form.trim() : null,
      limit: limit,
      offset: offset,
    );

    final Response<dynamic> res = await dio.getUri(uri);

    final Map<String, Object?> body = switch (res.data) {
      final Map<String, Object?> m => m,
      final Map m => m.cast<String, Object?>(),
      final String s => _asMap(jsonDecode(s)),
      _ => throw StateError('Unexpected tiles payload'),
    };

    final List<Map<String, Object?>> rawItems = _asListOfMaps(body['items']);
    final List<CatalogTile> items = rawItems
        .map(CatalogTile.fromJson)
        .toList(growable: false);

    final Object? nextOffset = body['nextOffset'];
    final int? next = switch (nextOffset) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v),
      _ => null,
    };

    final bool hasMore = next != null && items.isNotEmpty;
    return (items, hasMore);
  }
}
