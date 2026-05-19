// lib/features/retail/quotes/models/zoho_quote_line_item.dart

import 'package:afyakit/shared/utils/parse/primitives.dart';
import 'package:afyakit/shared/utils/utils.dart';

class ZohoQuoteLineItem {
  const ZohoQuoteLineItem({
    required this.name,
    required this.quantity,
    required this.rate,
    this.description,
    this.unit,
    this.lineItemId,
    this.itemTotal,
  });

  final String name;
  final String? description;

  /// Zoho usually returns this as a number. Internally we keep it as double
  /// because existing Zoho payloads may not always be typed consistently.
  final double quantity;

  final num rate;

  /// Optional display/sales unit.
  final String? unit;

  /// Used for update. If present, send it back as line_item_id.
  final String? lineItemId;

  final num? itemTotal;

  factory ZohoQuoteLineItem.fromJson(JsonMap j) {
    final String name = asTrimmedString(j['name']);
    final String? desc = asCleanStringOrNull(j['description']);

    final double qty = asDouble(j['quantity']);
    final num rate = asNum(j['rate']);

    final String? unit = asCleanStringOrNull(j['unit']);
    final String? id = asCleanStringOrNull(j['line_item_id']);

    final num? itemTotal = j.containsKey('item_total')
        ? asNum(j['item_total'], fallback: 0)
        : null;

    return ZohoQuoteLineItem(
      name: name.isEmpty ? 'Item' : name,
      description: desc,
      quantity: qty,
      rate: rate,
      unit: unit,
      lineItemId: id,
      itemTotal: itemTotal,
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'name': name,
      'description': description,
      'quantity': quantity,
      'rate': rate,
      'unit': unit,
      'line_item_id': lineItemId,
      'item_total': itemTotal,
    }..removeWhere(_removeEmpty);
  }

  ZohoQuoteLineItem copyWith({
    String? name,
    String? description,
    bool clearDescription = false,
    double? quantity,
    num? rate,
    String? unit,
    bool clearUnit = false,
    String? lineItemId,
    bool clearLineItemId = false,
    num? itemTotal,
    bool clearItemTotal = false,
  }) {
    return ZohoQuoteLineItem(
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      unit: clearUnit ? null : (unit ?? this.unit),
      lineItemId: clearLineItemId ? null : (lineItemId ?? this.lineItemId),
      itemTotal: clearItemTotal ? null : (itemTotal ?? this.itemTotal),
    );
  }

  static bool _removeEmpty(Object? _, Object? value) {
    if (value == null) return true;
    if (value is String && value.trim().isEmpty) return true;
    return false;
  }
}
