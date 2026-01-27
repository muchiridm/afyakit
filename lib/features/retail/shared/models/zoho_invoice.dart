import 'package:afyakit/shared/utils/utils.dart';

import 'zoho_invoice_payment.dart';

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
    final j = json.cast<String, Object?>();

    final name = readString(j['name']);
    final desc = readStringOrNull(j['description']);

    final qty = _readDouble(j['quantity']);
    final rate = readNum(j['rate']);

    final id = readStringOrNull(j['line_item_id']);
    final itemTotal = j.containsKey('item_total')
        ? readNum(j['item_total'])
        : null;

    return ZohoInvoiceLineItem(
      name: name.isEmpty ? 'Item' : name,
      description: desc,
      quantity: qty,
      rate: rate,
      lineItemId: id,
      itemTotal: itemTotal,
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
    this.customerId,
    this.customerEmail,
    this.contactPersonIds = const <String>[],
    this.notes,
    this.terms,
    this.dueDate,
    this.balance,
    this.lineItems = const <ZohoInvoiceLineItem>[],
    this.payments = const <ZohoInvoicePayment>[],
  });

  final String invoiceId;
  final String customerName;
  final String status;
  final DateTime? date;
  final num total;

  final String? invoiceNumber;
  final String? referenceNumber;
  final String? currencyCode;

  final String? customerId;

  /// Convenience only; Zoho email endpoint prefers contact_person_ids.
  final String? customerEmail;

  final List<String> contactPersonIds;

  final String? notes;
  final String? terms;

  final DateTime? dueDate;
  final num? balance;

  final List<ZohoInvoiceLineItem> lineItems;
  final List<ZohoInvoicePayment> payments;

  bool get hasRecipients =>
      contactPersonIds.isNotEmpty || (customerEmail ?? '').trim().isNotEmpty;

  factory ZohoInvoice.fromJson(JsonMap json) {
    final j = json.cast<String, Object?>();

    final id = readString(j['invoice_id'] ?? j['id']);
    final number = readStringOrNull(j['invoice_number']);

    final name = readString(j['customer_name'] ?? j['contact_name']);
    final status = readString(j['status']);

    final date = readDateTime(j['date']);
    final dueDate = readDateTime(j['due_date']);

    final total = readNum(j['total']);
    final balance = j.containsKey('balance') ? readNum(j['balance']) : null;

    final ref = readStringOrNull(j['reference_number'] ?? j['reference']);
    final currency = readStringOrNull(j['currency_code']);

    final customerId = readStringOrNull(j['customer_id']);
    final notes = readStringOrNull(j['notes']);
    final terms = readStringOrNull(j['terms']);

    // ───────────────────────── Line items ─────────────────────────
    final lines = _parseLineItems(j['line_items']);

    // ───────────────────────── Payments (best-effort) ─────────────────────────
    final pays = _parsePayments(j['payments'] ?? j['payment_details']);

    // ───────────────────────── Recipients (best-effort) ─────────────────────────
    final cpIds = <String>[];
    cpIds.addAll(_extractContactPersonIds(j['contact_persons']));
    cpIds.addAll(
      _extractContactPersonIds(
        j['contact_person_details'] ?? j['contact_persons_details'],
      ),
    );

    final dedupedCpIds = _dedupePreserveOrder(cpIds);

    final email = readStringOrNull(
      j['email'] ?? j['customer_email'] ?? j['contact_email'],
    );

    return ZohoInvoice(
      invoiceId: id,
      invoiceNumber: number,
      customerName: name,
      status: status,
      date: date,
      dueDate: dueDate,
      total: total,
      balance: balance,
      referenceNumber: ref,
      currencyCode: currency,
      customerId: customerId,
      customerEmail: email,
      contactPersonIds: dedupedCpIds,
      notes: notes,
      terms: terms,
      lineItems: lines,
      payments: pays,
    );
  }
}

// ─────────────────────────────────────────────
// Helpers (small + strict)
// Keep here unless you add them to utils.dart.
// ─────────────────────────────────────────────

double _readDouble(Object? v, {double fallback = 0}) {
  if (v is num) return v.toDouble();
  final s = readString(v);
  if (s.isEmpty) return fallback;
  return double.tryParse(s) ?? fallback;
}

List<ZohoInvoiceLineItem> _parseLineItems(Object? raw) {
  final out = <ZohoInvoiceLineItem>[];
  if (raw is! List) return out;

  for (final e in raw) {
    if (!isRecord(e)) continue;
    final m = (e as Map).cast<String, dynamic>();
    out.add(ZohoInvoiceLineItem.fromJson(m));
  }

  return out;
}

List<ZohoInvoicePayment> _parsePayments(Object? raw) {
  final out = <ZohoInvoicePayment>[];
  if (raw is! List) return out;

  for (final e in raw) {
    if (!isRecord(e)) continue;
    final m = (e as Map).cast<String, dynamic>();
    out.add(ZohoInvoicePayment.fromJson(m));
  }

  return out;
}

List<String> _extractContactPersonIds(Object? cps) {
  final out = <String>[];

  // 1) ["id1","id2"]
  if (cps is List) {
    for (final e in cps) {
      final id = readStringOrNull(e);
      if (id != null) out.add(id);
    }
  }

  // 2) [{contact_person_id:"..."}, ...]
  if (cps is List) {
    for (final e in cps) {
      if (!isRecord(e)) continue;
      final m = (e as Map).cast<String, Object?>();
      final id = readStringOrNull(m['contact_person_id'] ?? m['id']);
      if (id != null) out.add(id);
    }
  }

  return out;
}

List<String> _dedupePreserveOrder(List<String> xs) {
  final seen = <String>{};
  final out = <String>[];
  for (final x in xs) {
    if (seen.add(x)) out.add(x);
  }
  return out;
}
