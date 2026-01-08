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

  // strict helpers
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

    return DiSalesTile(
      canonKey: _s(j['canon_key']) ?? '',
      groupKey: _s(j['group_key']) ?? (_s(j['canon_key']) ?? ''),
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

class Paged<T> {
  const Paged({
    required this.items,
    required this.total,
    required this.offset,
    required this.nextOffset,
  });

  final List<T> items;
  final int total;
  final int offset;
  final int? nextOffset;

  static int _i(Object? v, {required int def}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return def;
  }

  static Map<String, Object?> _m(Object? v) {
    if (v is Map) return v.cast<String, Object?>();
    return const <String, Object?>{};
  }

  static Paged<T> fromJson<T>(
    Object? raw,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final j = _m(raw);

    final itemsRaw = j['items'];
    final items = <T>[];
    if (itemsRaw is List) {
      for (final it in itemsRaw) {
        if (it is Map) {
          items.add(itemFromJson(it.cast<String, dynamic>()));
        }
      }
    }

    final total = _i(j['total'], def: items.length);
    final offset = _i(j['offset'], def: 0);

    int? nextOffset;
    final no = j['nextOffset'] ?? j['next_offset'];
    if (no is int) nextOffset = no;
    if (no is num) nextOffset = no.toInt();

    return Paged(
      items: items,
      total: total,
      offset: offset,
      nextOffset: nextOffset,
    );
  }
}
