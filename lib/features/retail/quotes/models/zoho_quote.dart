// lib/features/retail/sales/quotes/models/zoho_quote.dart

typedef JsonMap = Map<String, dynamic>;

String _s(dynamic v) => (v ?? '').toString().trim();

DateTime? _parseDate(dynamic v) {
  final s = _s(v);
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

num _parseNum(dynamic v, {num fallback = 0}) {
  if (v is num) return v;
  final s = _s(v);
  return num.tryParse(s) ?? fallback;
}

double _parseDouble(dynamic v, {double fallback = 0}) {
  if (v is num) return v.toDouble();
  final s = _s(v);
  return double.tryParse(s) ?? fallback;
}

String? _cleanOrNull(dynamic v) {
  final s = _s(v);
  return s.isEmpty ? null : s;
}

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

  /// ✅ Used for update. If present, send it back as line_item_id.
  final String? lineItemId;

  final num? itemTotal;

  factory ZohoQuoteLineItem.fromJson(JsonMap j) {
    final name = _s(j['name']);
    final desc = _cleanOrNull(j['description']);

    final qty = _parseDouble(j['quantity']);
    final rate = _parseNum(j['rate']);

    final id = _cleanOrNull(j['line_item_id']);
    final itemTotal = j.containsKey('item_total')
        ? _parseNum(j['item_total'], fallback: 0)
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

class ZohoQuote {
  const ZohoQuote({
    required this.quoteId,
    required this.customerName,
    required this.status,
    required this.date,
    required this.total,
    this.referenceNumber,
    this.currencyCode,
    this.customerId,
    this.notes,
    this.terms,
    this.lineItems = const <ZohoQuoteLineItem>[],
  });

  final String quoteId;
  final String customerName;
  final String status;
  final DateTime? date;
  final num total;

  final String? referenceNumber;
  final String? currencyCode;

  /// Zoho: estimate.customer_id / contact_id
  final String? customerId;

  final String? notes;
  final String? terms;

  final List<ZohoQuoteLineItem> lineItems;

  factory ZohoQuote.fromJson(JsonMap j) {
    final id = _s(j['estimate_id'] ?? j['quote_id'] ?? j['id']);
    final name = _s(j['customer_name'] ?? j['contact_name']);
    final status = _s(j['status']);

    final date = _parseDate(j['date'] ?? j['estimate_date']);
    final total = _parseNum(j['total']);

    final reference = _cleanOrNull(j['reference_number'] ?? j['reference']);
    final currency = _cleanOrNull(j['currency_code']);

    final customerId = _cleanOrNull(j['customer_id']);

    final notes = _cleanOrNull(j['notes']);
    final terms = _cleanOrNull(j['terms']);

    final rawLines = j['line_items'];
    final lines = <ZohoQuoteLineItem>[];
    if (rawLines is List) {
      for (final e in rawLines) {
        if (e is Map) {
          lines.add(ZohoQuoteLineItem.fromJson(e.cast<String, dynamic>()));
        }
      }
    }

    return ZohoQuote(
      quoteId: id,
      customerName: name,
      status: status,
      date: date,
      total: total,
      referenceNumber: reference,
      currencyCode: currency,
      customerId: customerId,
      notes: notes,
      terms: terms,
      lineItems: lines,
    );
  }
}
