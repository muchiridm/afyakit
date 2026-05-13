// lib/features/retail/catalog/models/di_sales_tile.dart

class DiSalesTile {
  const DiSalesTile({
    required this.canonKey,
    required this.groupKey,
    required this.tileTitle,
    this.tileDesc,
    this.form,
    this.bestPackCount,
    required this.offerCount,
    this.bestSellPrice,
    this.bestSupplier,
    this.priceRequestRequired,
  });

  final String canonKey;
  final String groupKey;
  final String tileTitle;
  final String? tileDesc;

  final String? form;
  final int? bestPackCount;
  final int offerCount;

  final num? bestSellPrice;
  final String? bestSupplier;

  final bool? priceRequestRequired;

  // ─────────────────────────────────────────────────────────────
  // Edit-mode helper: build a safe tile from a Zoho line item
  // ─────────────────────────────────────────────────────────────

  /// Creates a "best-effort" tile when editing a quote loaded from Zoho.
  ///
  /// If [canonKey]/[groupKey] are provided (e.g. Zoho line_item_id),
  /// they will be used as stable keys. Otherwise we derive from name.
  static DiSalesTile fallbackFromName({
    required String name,
    String? description,
    num? bestSellPrice,
    int? bestPackCount,
    String? bestSupplier,
    bool? priceRequestRequired,
    String? form,
    String? canonKey,
    String? groupKey,
  }) {
    final title = name.trim().isEmpty ? 'Item' : name.trim();
    final desc = (description ?? '').trim();

    final ck = (canonKey ?? '').trim();
    final gk = (groupKey ?? '').trim();

    final derived = _tenantIdKey(title);
    final resolvedCanonKey = ck.isNotEmpty ? ck : derived;
    final resolvedGroupKey = gk.isNotEmpty ? gk : resolvedCanonKey;

    return DiSalesTile(
      canonKey: resolvedCanonKey,
      groupKey: resolvedGroupKey,
      tileTitle: title,
      tileDesc: desc.isEmpty ? null : desc,
      form: (form ?? '').trim().isEmpty ? null : form!.trim(),
      bestPackCount: bestPackCount,
      offerCount: 0,
      bestSellPrice: bestSellPrice,
      bestSupplier: (bestSupplier ?? '').trim().isEmpty
          ? null
          : bestSupplier!.trim(),
      priceRequestRequired: priceRequestRequired,
    );
  }

  static String _tenantIdKey(String s) {
    final t = s.trim().toLowerCase();
    final cleaned = t
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'line' : cleaned;
  }

  static String? _s(Object? v) {
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    return null;
  }

  static int? _i(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
  static num? _n(Object? v) => v is num ? v : null;
  static bool? _b(Object? v) => v is bool ? v : null;

  factory DiSalesTile.fromJson(Map<String, dynamic> json) {
    final j = json.cast<String, Object?>();

    final canon = _s(j['canon_key']) ?? '';
    final group = _s(j['group_key']) ?? canon;

    return DiSalesTile(
      canonKey: canon,
      groupKey: group,
      tileTitle: _s(j['tile_title']) ?? '',
      tileDesc: _s(j['tile_desc']),
      form: _s(j['form']),
      bestPackCount: _i(j['best_pack_count']),
      offerCount: _i(j['offer_count']) ?? 0,
      bestSellPrice: _n(j['best_sell_price']),
      bestSupplier: _s(j['best_supplier']),
      priceRequestRequired: _b(j['price_request_required']),
    );
  }
}
