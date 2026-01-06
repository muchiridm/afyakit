// lib/core/catalog/catalog_models.dart

import 'package:flutter/foundation.dart';

@immutable
class CatalogTile {
  /// canon_key (preferred) or other fallback
  final String id;
  final String brand;
  final String strengthSig;

  /// normalized formulation from BE: tablet|capsule|liquid|injection|other
  final String form;

  final num? bestSellPrice;
  final int? offerCount;

  // extra fields that tiles engine emits
  final int? bestPackCount;
  final String? tileDesc;

  // newer extras
  final String? tileTitle;
  final String? bestSupplier;
  final String? packsFmt;
  final String? volumeSig;
  final String? concentrationSig;
  final bool? hasMergeOverride;

  const CatalogTile({
    required this.id,
    required this.brand,
    required this.strengthSig,
    required this.form,
    this.bestSellPrice,
    this.offerCount,
    this.bestPackCount,
    this.tileDesc,
    this.tileTitle,
    this.bestSupplier,
    this.packsFmt,
    this.volumeSig,
    this.concentrationSig,
    this.hasMergeOverride,
  });

  factory CatalogTile.fromJson(Map<String, Object?> j) => CatalogTile(
    // BE usually sends canon_key; keep old fallbacks just in case
    id:
        (j['id'] ?? j['canon_key'] ?? j['cluster_key'] ?? j['sku'] ?? '')
            as String,
    brand: (j['brand'] ?? '') as String,
    strengthSig: (j['strength_sig'] ?? '') as String,
    form: (j['form'] ?? '') as String,
    bestSellPrice: j['best_sell_price'] as num?,
    offerCount: j['offer_count'] as int?,
    // extra
    bestPackCount: j['best_pack_count'] as int?,
    tileDesc: j['tile_desc'] as String?,
    tileTitle: j['tile_title'] as String?,
    bestSupplier: j['best_supplier'] as String?,
    packsFmt: j['packs_fmt'] as String?,
    volumeSig: j['volume_sig'] as String?,
    concentrationSig: j['concentration_sig'] as String?,
    hasMergeOverride: j['has_merge_override'] as bool?,
  );
}

@immutable
class CatalogQuery {
  final String q; // search
  /// '', 'tablet', 'capsule', 'liquid', 'injection', 'other'
  final String form;
  final String sort; // reserved

  const CatalogQuery({this.q = '', this.form = '', this.sort = ''});

  CatalogQuery copyWith({String? q, String? form, String? sort}) =>
      CatalogQuery(
        q: q ?? this.q,
        form: form ?? this.form,
        sort: sort ?? this.sort,
      );
}
