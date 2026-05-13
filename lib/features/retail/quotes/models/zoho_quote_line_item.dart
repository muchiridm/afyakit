// lib/features/retail/quotes/models/zoho_quote_line_item.dart

import 'package:afyakit/shared/utils/parse/primitives.dart';
import 'package:afyakit/shared/utils/utils.dart';

class ZohoQuoteLineItem {
  const ZohoQuoteLineItem({
    required this.name,
    required this.quantity,
    required this.rate,
    this.description,
    this.lineItemId,
    this.itemTotal,
  });

  final String name;
  final String? description;
  final double quantity;
  final num rate;

  /// Used for update. If present, send it back as line_item_id.
  final String? lineItemId;

  final num? itemTotal;

  factory ZohoQuoteLineItem.fromJson(JsonMap j) {
    final name = asTrimmedString(j['name']);
    final desc = asCleanStringOrNull(j['description']);

    final qty = asDouble(j['quantity']);
    final rate = asNum(j['rate']);

    final id = asCleanStringOrNull(j['line_item_id']);
    final itemTotal = j.containsKey('item_total')
        ? asNum(j['item_total'], fallback: 0)
        : null;

    return ZohoQuoteLineItem(
      name: name.isEmpty ? 'Item' : name,
      description: desc,
      quantity: qty,
      rate: rate,
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
