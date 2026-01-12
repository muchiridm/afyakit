typedef JsonMap = Map<String, dynamic>;

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

  /// ✅ Used for update. If present, send it back as line_item_id.
  final String? lineItemId;

  final num? itemTotal;

  factory ZohoInvoiceLineItem.fromJson(JsonMap j) {
    final name = (j['name'] ?? '').toString().trim();
    final desc = (j['description'] ?? '').toString().trim();
    final qRaw = j['quantity'];
    final rRaw = j['rate'];

    final qty = qRaw is num ? qRaw.toDouble() : double.tryParse('$qRaw') ?? 0.0;
    final rate = rRaw is num ? rRaw : num.tryParse('$rRaw') ?? 0;

    final id = (j['line_item_id'] ?? '').toString().trim();
    final totalRaw = j['item_total'];

    return ZohoInvoiceLineItem(
      name: name,
      description: desc.isEmpty ? null : desc,
      quantity: qty,
      rate: rate,
      lineItemId: id.isEmpty ? null : id,
      itemTotal: totalRaw is num ? totalRaw : num.tryParse('$totalRaw'),
    );
  }
}

class ZohoInvoice {
  const ZohoInvoice({
    required this.invoiceId,
    required this.customerName,
    required this.status,
    required this.date,
    required this.total,
    this.invoiceNumber,
    this.referenceNumber,
    this.currencyCode,

    // ✅ Optional full invoice fields (present on getInvoice)
    this.customerId,
    this.notes,
    this.terms,
    this.dueDate,
    this.balance,
    this.lineItems = const <ZohoInvoiceLineItem>[],
  });

  final String invoiceId;
  final String customerName;
  final String status; // keep open-ended
  final DateTime? date;
  final num total;

  final String? invoiceNumber;
  final String? referenceNumber;
  final String? currencyCode;

  /// ✅ Full invoice payload: customer_id (contact_id)
  final String? customerId;

  /// ✅ Full invoice payload extras
  final String? notes;
  final String? terms;

  final DateTime? dueDate;
  final num? balance;

  /// ✅ Full invoice payload line_items (needed for edit)
  final List<ZohoInvoiceLineItem> lineItems;

  factory ZohoInvoice.fromJson(JsonMap j) {
    final id = (j['invoice_id'] ?? j['id'] ?? '').toString().trim();
    final number = (j['invoice_number'] ?? '').toString().trim();
    final name = (j['customer_name'] ?? j['contact_name'] ?? '').toString();
    final status = (j['status'] ?? '').toString();

    DateTime? date;
    final rawDate = j['date'];
    if (rawDate is String && rawDate.trim().isNotEmpty) {
      date = DateTime.tryParse(rawDate.trim());
    }

    DateTime? dueDate;
    final rawDue = j['due_date'];
    if (rawDue is String && rawDue.trim().isNotEmpty) {
      dueDate = DateTime.tryParse(rawDue.trim());
    }

    final totalRaw = j['total'];
    final total = totalRaw is num ? totalRaw : num.tryParse('$totalRaw') ?? 0;

    final balRaw = j['balance'];
    final balance = balRaw is num ? balRaw : num.tryParse('$balRaw');

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
    final lines = <ZohoInvoiceLineItem>[];
    if (rawLines is List) {
      for (final e in rawLines) {
        if (e is Map) {
          lines.add(ZohoInvoiceLineItem.fromJson(e.cast<String, dynamic>()));
        }
      }
    }

    return ZohoInvoice(
      invoiceId: id,
      invoiceNumber: number.isEmpty ? null : number,
      customerName: name,
      status: status,
      date: date,
      dueDate: dueDate,
      total: total,
      balance: balance,
      referenceNumber: ref,
      currencyCode: currency,
      customerId: customerId,
      notes: notes,
      terms: terms,
      lineItems: lines,
    );
  }
}
