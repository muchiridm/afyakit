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
}
