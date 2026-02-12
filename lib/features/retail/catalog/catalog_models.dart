// lib/features/retail/catalog/catalog_models.dart

import 'package:flutter/foundation.dart';

@immutable
class CatalogTile {
  /// Stable identity for cart + quote lines.
  /// Prefer canon_key/cluster_key; avoid generic "id".
  final String id;

  final String brand;
  final String strengthSig;

  /// formulation from BE can be anything now (tablet, syrup, ointment, ...)
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

  /// Decorated manufacturer for the tile (aggregated from variants)
  /// BE field: supplier_manufacturer
  final String? supplierManufacturer;

  /// If true, BE is telling us "do not merge this tile purely by canon_key".
  /// We use this to salt the id so cart/quote lines don't collapse.
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
    this.supplierManufacturer,
    this.hasMergeOverride,
  });

  // Useful for UI
  String get titleLine => '${brand.trim()} ${strengthSig.trim()}'.trim();
  bool get hasSupplierManufacturer =>
      supplierManufacturer != null && supplierManufacturer!.trim().isNotEmpty;

  static String _asString(Object? v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is num || v is bool) return v.toString();
    return v.toString();
  }

  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  static num? _asNum(Object? v) {
    if (v == null) return null;
    if (v is num) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return num.tryParse(s);
  }

  static bool? _asBool(Object? v) {
    if (v == null) return null;
    if (v is bool) return v;
    final s = v.toString().trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return null;
  }

  static String _fingerprint({
    required String brand,
    required String strengthSig,
    required String form,
    String? title,
    String? desc,
    num? price,
  }) {
    final b = brand.trim().toLowerCase();
    final s = strengthSig.trim().toLowerCase();
    final f = form.trim().toLowerCase();
    final t = (title ?? '').trim().toLowerCase();
    final d = (desc ?? '').trim().toLowerCase();
    final p = price == null ? '' : price.toString();

    return [
      'fp',
      b.isEmpty ? '_' : b,
      s.isEmpty ? '_' : s,
      f.isEmpty ? '_' : f,
      t.isEmpty ? '_' : t,
      d.isEmpty ? '_' : d,
      p.isEmpty ? '_' : p,
    ].join('|');
  }

  factory CatalogTile.fromJson(Map<String, Object?> j) {
    final brand = _asString(j['brand']);
    final strengthSig = _asString(j['strength_sig']);
    final form = _asString(j['form']);

    final title = _asString(j['tile_title']).trim();
    final desc = _asString(j['tile_desc']).trim();

    final price = _asNum(j['best_sell_price']);
    final hasMergeOverride = _asBool(j['has_merge_override']);

    final canonKey = _asString(j['canon_key']).trim();
    final clusterKey = _asString(j['cluster_key']).trim();
    final sku = _asString(j['sku']).trim();
    final legacyId = _asString(j['id']).trim();

    var baseId = canonKey.isNotEmpty
        ? canonKey
        : (clusterKey.isNotEmpty
              ? clusterKey
              : (sku.isNotEmpty
                    ? sku
                    : (legacyId.isNotEmpty
                          ? legacyId
                          : _fingerprint(
                              brand: brand,
                              strengthSig: strengthSig,
                              form: form,
                              title: title,
                              desc: desc,
                              price: price,
                            ))));

    if (hasMergeOverride == true) {
      final salt = [
        title.isEmpty ? '_' : title,
        desc.isEmpty ? '_' : desc,
        price == null ? '_' : price.toString(),
        _asString(j['best_supplier']).trim().isEmpty
            ? '_'
            : _asString(j['best_supplier']).trim(),
        _asString(j['packs_fmt']).trim().isEmpty
            ? '_'
            : _asString(j['packs_fmt']).trim(),
      ].join('|');

      baseId = '$baseId||$salt';
    }

    final bestSupplier = _asString(j['best_supplier']).trim();
    final packsFmt = _asString(j['packs_fmt']).trim();
    final volumeSig = _asString(j['volume_sig']).trim();
    final concentrationSig = _asString(j['concentration_sig']).trim();

    final supplierMfg = _asString(j['supplier_manufacturer']).trim();

    return CatalogTile(
      id: baseId,
      brand: brand,
      strengthSig: strengthSig,
      form: form,
      bestSellPrice: price,
      offerCount: _asInt(j['offer_count']),
      bestPackCount: _asInt(j['best_pack_count']),
      tileDesc: desc.isEmpty ? null : desc,
      tileTitle: title.isEmpty ? null : title,
      bestSupplier: bestSupplier.isEmpty ? null : bestSupplier,
      packsFmt: packsFmt.isEmpty ? null : packsFmt,
      volumeSig: volumeSig.isEmpty ? null : volumeSig,
      concentrationSig: concentrationSig.isEmpty ? null : concentrationSig,
      supplierManufacturer: supplierMfg.isEmpty ? null : supplierMfg,
      hasMergeOverride: hasMergeOverride,
    );
  }
}

@immutable
class CatalogQuery {
  final String q; // search
  final String form; // '', 'tablet', 'syrup', ...
  final String sort; // reserved

  const CatalogQuery({this.q = '', this.form = '', this.sort = ''});

  CatalogQuery copyWith({String? q, String? form, String? sort}) =>
      CatalogQuery(
        q: q ?? this.q,
        form: form ?? this.form,
        sort: sort ?? this.sort,
      );
}
