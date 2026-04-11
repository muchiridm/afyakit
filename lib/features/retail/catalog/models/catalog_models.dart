import 'package:flutter/foundation.dart';

@immutable
class CatalogTile {
  final String id;

  final String brand;
  final String strengthSig;
  final String form;

  final num? bestSellPrice;
  final int? offerCount;

  final int? bestPackCount;
  final String? tileDesc;

  final String? tileTitle;
  final String? bestSupplier;
  final String? packsFmt;
  final String? volumeSig;
  final String? concentrationSig;
  final String? supplierManufacturer;

  final String? whoPath;
  final String? whoPrimaryInn;
  final String? whoAtcCode;
  final String? whoAtcName;

  final List<String>? whoMappedInns;
  final List<String>? whoAtcCodes;
  final List<String>? whoAtcLabels;

  final bool? hasMergeOverride;

  final String? uiKey;
  final String? groupKey;
  final bool priceRequestRequired;

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
    this.whoPath,
    this.whoPrimaryInn,
    this.whoAtcCode,
    this.whoAtcName,
    this.whoMappedInns,
    this.whoAtcCodes,
    this.whoAtcLabels,
    this.hasMergeOverride,
    this.uiKey,
    this.groupKey,
    this.priceRequestRequired = false,
  });

  String get titleLine => '${brand.trim()} ${strengthSig.trim()}'.trim();

  bool get hasSupplierManufacturer =>
      supplierManufacturer != null && supplierManufacturer!.trim().isNotEmpty;

  bool get hasComboWhoMappings =>
      (whoMappedInns != null && whoMappedInns!.length > 1) ||
      (whoAtcCodes != null && whoAtcCodes!.length > 1);

  String get groupingKey {
    final ui = uiKey?.trim();
    if (ui != null && ui.isNotEmpty) return ui;
    return '${brand.trim().toLowerCase()}|'
        '${strengthSig.trim().toLowerCase()}|'
        '${form.trim().toLowerCase()}';
  }

  String? get whoPathPreview {
    final raw = whoPath?.trim() ?? '';
    if (raw.isEmpty) return null;

    final parts = raw
        .split('>')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) return raw;
    if (parts.length <= 3) return parts.join(' > ');
    return parts.sublist(parts.length - 3).join(' > ');
  }

  String? get comboWhoSummary {
    final labels = whoAtcLabels ?? const <String>[];
    final inns = whoMappedInns ?? const <String>[];

    if (labels.isEmpty && inns.isEmpty) return null;

    final parts = <String>[
      if (labels.isNotEmpty) labels.join(', '),
      if (inns.isNotEmpty) 'Ingredients: ${inns.join(', ')}',
    ];

    return parts.join(' • ');
  }

  String? get tileDescWithWhoPath {
    final desc = tileDesc?.trim() ?? '';
    final who = whoPathPreview?.trim() ?? '';
    final atc = whoAtcCode?.trim() ?? '';
    final combo = comboWhoSummary?.trim() ?? '';

    if (desc.isEmpty && who.isEmpty && atc.isEmpty && combo.isEmpty) {
      return null;
    }

    final extras = [
      if (atc.isNotEmpty) 'ATC $atc',
      if (who.isNotEmpty) who,
      if (combo.isNotEmpty && combo != who) combo,
    ].join(' • ');

    if (desc.isEmpty) return extras.isEmpty ? null : extras;
    if (extras.isEmpty) return desc;

    return '$desc • $extras';
  }

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

  static List<String>? _asStringList(Object? v) {
    if (v is! List) return null;
    final out = v
        .map((e) => _asString(e).trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return out.isEmpty ? null : out;
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
    final whoPath = _asString(j['who_path']).trim();
    final whoPrimaryInn = _asString(j['who_primary_inn']).trim();
    final whoAtcCode = _asString(j['who_atc_code']).trim();
    final whoAtcName = _asString(j['who_atc_name']).trim();

    final whoMappedInns = _asStringList(j['who_mapped_inns']);
    final whoAtcCodes = _asStringList(j['who_atc_codes']);
    final whoAtcLabels = _asStringList(j['who_atc_labels']);

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
    final uiKey = _asString(j['ui_key']).trim();
    final groupKey = _asString(j['group_key']).trim();

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
      whoPath: whoPath.isEmpty ? null : whoPath,
      whoPrimaryInn: whoPrimaryInn.isEmpty ? null : whoPrimaryInn,
      whoAtcCode: whoAtcCode.isEmpty ? null : whoAtcCode,
      whoAtcName: whoAtcName.isEmpty ? null : whoAtcName,
      whoMappedInns: whoMappedInns,
      whoAtcCodes: whoAtcCodes,
      whoAtcLabels: whoAtcLabels,
      hasMergeOverride: hasMergeOverride,
      uiKey: uiKey.isEmpty ? null : uiKey,
      groupKey: groupKey.isEmpty ? null : groupKey,
      priceRequestRequired: _asBool(j['price_request_required']) ?? false,
    );
  }
}

@immutable
class CatalogQuery {
  final String q;
  final String form;
  final String sort;

  const CatalogQuery({this.q = '', this.form = '', this.sort = ''});

  CatalogQuery copyWith({String? q, String? form, String? sort}) {
    return CatalogQuery(
      q: q ?? this.q,
      form: form ?? this.form,
      sort: sort ?? this.sort,
    );
  }

  CatalogQuery get normalized => CatalogQuery(
    q: q.trim(),
    form: form.trim().toLowerCase(),
    sort: sort.trim().toLowerCase(),
  );

  bool get isDiscoveryMode => normalized.q.isEmpty && normalized.form.isEmpty;
}
