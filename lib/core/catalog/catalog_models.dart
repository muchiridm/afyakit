// lib/core/catalog/catalog_models.dart

import 'package:flutter/foundation.dart';

@immutable
class CatalogTile {
  final String id;
  final String brand;
  final String strengthSig;
  final String form;
  final num? bestSellPrice;
  final int? offerCount;

  const CatalogTile({
    required this.id,
    required this.brand,
    required this.strengthSig,
    required this.form,
    this.bestSellPrice,
    this.offerCount,
  });

  factory CatalogTile.fromJson(Map<String, Object?> j) => CatalogTile(
    id: (j['id'] ?? j['cluster_key'] ?? j['sku'] ?? '') as String,
    brand: (j['brand'] ?? '') as String,
    strengthSig: (j['strength_sig'] ?? '') as String,
    form: (j['form'] ?? '') as String,
    bestSellPrice: j['best_sell_price'] as num?,
    offerCount: j['offer_count'] as int?,
  );
}

@immutable
class CatalogQuery {
  final String q; // search
  final String form; // '', 'tablet', ...
  final String sort; // reserved (e.g. 'price_asc')

  const CatalogQuery({this.q = '', this.form = '', this.sort = ''});

  CatalogQuery copyWith({String? q, String? form, String? sort}) =>
      CatalogQuery(
        q: q ?? this.q,
        form: form ?? this.form,
        sort: sort ?? this.sort,
      );
}
