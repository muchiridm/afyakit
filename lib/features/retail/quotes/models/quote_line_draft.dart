import 'package:afyakit/features/retail/catalog/models/di_sales_tile.dart';
import 'package:flutter/foundation.dart';

@immutable
class QuoteLineDraft {
  const QuoteLineDraft({
    required this.tile,
    required this.quantity,
    required this.rate,
    this.description,
    this.lineItemId,
    this.zohoItemId,
    this.unit,
  });

  final DiSalesTile tile;
  final int quantity;
  final num rate;

  final String? description;
  final String? lineItemId;
  final String? zohoItemId;
  final String? unit;

  String get key {
    final String id = (lineItemId ?? '').trim();
    if (id.isNotEmpty) return id;

    final String canonKey = tile.canonKey.trim();
    if (canonKey.isNotEmpty) return canonKey;

    final String groupKey = tile.groupKey.trim();
    if (groupKey.isNotEmpty) return groupKey;

    final String title = tile.tileTitle.trim();
    return title.isNotEmpty ? title : 'line';
  }

  int get safeQty {
    if (quantity < 0) return 0;
    if (quantity > 9999) return 9999;
    return quantity;
  }

  num get safeRate {
    if (rate.isNaN || rate.isInfinite || rate < 0) return 0;
    return rate;
  }

  num get amount => safeRate * safeQty;

  QuoteLineDraft copyWith({
    DiSalesTile? tile,
    int? quantity,
    num? rate,
    String? description,
    bool clearDescription = false,
    String? lineItemId,
    bool clearLineItemId = false,
    String? zohoItemId,
    bool clearZohoItemId = false,
    String? unit,
    bool clearUnit = false,
  }) {
    return QuoteLineDraft(
      tile: tile ?? this.tile,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      description: clearDescription ? null : (description ?? this.description),
      lineItemId: clearLineItemId ? null : (lineItemId ?? this.lineItemId),
      zohoItemId: clearZohoItemId ? null : (zohoItemId ?? this.zohoItemId),
      unit: clearUnit ? null : (unit ?? this.unit),
    );
  }
}
