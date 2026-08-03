// lib/features/retail/invoices/models/zoho_invoice_line_item.dart

import 'package:afyakit/shared/utils/utils.dart';

class ZohoInvoiceLineItem {
  const ZohoInvoiceLineItem({
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
  final String? lineItemId;
  final num? itemTotal;

  factory ZohoInvoiceLineItem.fromJson(JsonMap json) {
    final JsonMap j = json.cast<String, dynamic>();

    final String name = readString(j['name']);
    final String? desc = readStringOrNull(j['description']);

    final double qty = readDouble(j['quantity']);
    final num rate = readNum(j['rate']);

    final String? id = readStringOrNull(j['line_item_id']);
    final num? itemTotal = readNumOrNull(j['item_total']);

    return ZohoInvoiceLineItem(
      name: name.isEmpty ? 'Item' : name,
      description: desc,
      quantity: qty,
      rate: rate,
      lineItemId: id,
      itemTotal: itemTotal,
    );
  }

  JsonMap toJson() {
    return <String, Object?>{
      'line_item_id': lineItemId,
      'name': name,
      'description': description,
      'quantity': quantity,
      'rate': rate,
      'item_total': itemTotal,
    }..removeWhere(removeEmpty);
  }
}
