// lib/features/retail/sales/quotes/models/zoho_quote.dart

typedef JsonMap = Map<String, dynamic>;

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
    final name = (j['name'] ?? '').toString().trim();
    final descRaw = (j['description'] ?? '').toString().trim();

    final qRaw = j['quantity'];
    final rRaw = j['rate'];

    final qty = qRaw is num ? qRaw.toDouble() : double.tryParse('$qRaw') ?? 0.0;
    final rate = rRaw is num ? rRaw : num.tryParse('$rRaw') ?? 0;

    final id = (j['line_item_id'] ?? '').toString().trim();
    final totalRaw = j['item_total'];

    final desc = descRaw.isEmpty ? null : descRaw;

    return ZohoQuoteLineItem(
      name: name,
      description: desc,
      quantity: qty,
      rate: rate,
      lineItemId: id.isEmpty ? null : id,
      itemTotal: totalRaw is num ? totalRaw : num.tryParse('$totalRaw'),
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

    // ✅ Optional full quote fields (present on getQuote)
    this.customerId,
    this.notes,
    this.terms,
    this.lineItems = const <ZohoQuoteLineItem>[],
  });

  final String quoteId;
  final String customerName;
  final String status; // "draft", "sent", etc.
  final DateTime? date;
  final num total;

  final String? referenceNumber;
  final String? currencyCode;

  /// ✅ Full quote payload: customer_id (contact_id)
  final String? customerId;

  /// ✅ Full quote payload extras (if returned by Zoho)
  final String? notes;
  final String? terms;

  /// ✅ Full quote payload line_items (needed for edit)
  final List<ZohoQuoteLineItem> lineItems;

  factory ZohoQuote.fromJson(JsonMap j) {
    final id = (j['estimate_id'] ?? j['quote_id'] ?? j['id'] ?? '')
        .toString()
        .trim();

    final name = (j['customer_name'] ?? j['contact_name'] ?? '')
        .toString()
        .trim();

    final status = (j['status'] ?? '').toString().trim();

    DateTime? date;
    final rawDate = j['date'] ?? j['estimate_date'];
    if (rawDate is String) {
      final s = rawDate.trim();
      if (s.isNotEmpty) date = DateTime.tryParse(s);
    }

    final totalRaw = j['total'];
    final total = totalRaw is num ? totalRaw : num.tryParse('$totalRaw') ?? 0;

    final refRaw = (j['reference_number'] ?? j['reference'] ?? '').toString();
    final ref = refRaw.trim().isEmpty ? null : refRaw.trim();

    final currencyRaw = (j['currency_code'] ?? '').toString();
    final currency = currencyRaw.trim().isEmpty ? null : currencyRaw.trim();

    final customerIdRaw = (j['customer_id'] ?? '').toString().trim();
    final customerId = customerIdRaw.isEmpty ? null : customerIdRaw;

    final notesRaw = (j['notes'] ?? '').toString().trim();
    final notes = notesRaw.isEmpty ? null : notesRaw;

    final termsRaw = (j['terms'] ?? '').toString().trim();
    final terms = termsRaw.isEmpty ? null : termsRaw;

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
      referenceNumber: ref,
      currencyCode: currency,
      customerId: customerId,
      notes: notes,
      terms: terms,
      lineItems: lines,
    );
  }
}
