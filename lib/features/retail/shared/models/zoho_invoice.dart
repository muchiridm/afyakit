// lib/features/retail/shared/models/zoho_invoice.dart

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

    final name = readString(j['name']).trim();
    final desc = readStringOrNull(j['description'])?.trim();

    final qty = _readDouble(j['quantity']);
    final rate = readNum(j['rate']);

    final id = readStringOrNull(j['line_item_id'])?.trim();
    final itemTotal = j.containsKey('item_total')
        ? readNum(j['item_total'])
        : null;

    return ZohoInvoiceLineItem(
      name: name.isEmpty ? 'Item' : name,
      description: (desc == null || desc.isEmpty) ? null : desc,
      quantity: qty,
      rate: rate,
      lineItemId: (id == null || id.isEmpty) ? null : id,
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
    this.accountNumber, // ✅ NEW (replaces referenceNumber)
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

  /// ✅ Your app identity key. Used for "mine" filtering & display.
  /// Comes from BE as `account_number` (preferred).
  final String? accountNumber;

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

    final id = readString(j['invoice_id'] ?? j['id']).trim();
    final number = readStringOrNull(j['invoice_number'])?.trim();

    final name = readString(j['customer_name'] ?? j['contact_name']).trim();
    final status = readString(j['status']).trim();

    final date = readDateTime(j['date']);
    final dueDate = readDateTime(j['due_date']);

    final total = readNum(j['total']);
    final balance = j.containsKey('balance') ? readNum(j['balance']) : null;

    // ✅ NEW: prefer BE-provided account_number, fallback to older keys
    final account = _cleanStringOrNull(
      j['account_number'] ??
          j['accountNumber'] ??
          // fallback for older payloads (not preferred)
          j['reference_number'] ??
          j['reference'],
    );

    final currency = _cleanStringOrNull(j['currency_code']);

    final customerId = _cleanStringOrNull(j['customer_id']);
    final notes = _cleanStringOrNull(j['notes']);
    final terms = _cleanStringOrNull(j['terms']);

    // ───────────────────────── Line items ─────────────────────────
    final lines = _parseLineItems(j['line_items']);

    // ───────────────────────── Payments (best-effort) ─────────────────────────
    final pays = _parsePayments(j['payments'] ?? j['payment_details']);

    // ───────────────────────── Recipients (best-effort) ─────────────────────────
    final cpIds = <String>[
      ..._extractContactPersonIds(j['contact_persons']),
      ..._extractContactPersonIds(
        j['contact_person_details'] ?? j['contact_persons_details'],
      ),
    ];
    final dedupedCpIds = _dedupePreserveOrder(cpIds);

    final email = _cleanStringOrNull(
      j['email'] ?? j['customer_email'] ?? j['contact_email'],
    );

    return ZohoInvoice(
      invoiceId: id,
      invoiceNumber: number,
      customerName: name.isEmpty ? 'Customer' : name,
      status: status.isEmpty ? 'unknown' : status,
      date: date,
      dueDate: dueDate,
      total: total,
      balance: balance,
      accountNumber: account, // ✅ NEW
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

String? _cleanStringOrNull(Object? v) {
  final s = readStringOrNull(v)?.trim();
  return (s == null || s.isEmpty) ? null : s;
}

double _readDouble(Object? v, {double fallback = 0}) {
  if (v is num) return v.toDouble();
  final s = readString(v).trim();
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

  if (cps is! List) return out;

  for (final e in cps) {
    // 1) "id"
    final id1 = readStringOrNull(e)?.trim();
    if (id1 != null && id1.isNotEmpty) {
      out.add(id1);
      continue;
    }

    // 2) {contact_person_id:"..."} or {id:"..."}
    if (!isRecord(e)) continue;
    final m = (e as Map).cast<String, Object?>();
    final id2 = readStringOrNull(m['contact_person_id'] ?? m['id'])?.trim();
    if (id2 != null && id2.isNotEmpty) out.add(id2);
  }

  return out;
}

List<String> _dedupePreserveOrder(List<String> xs) {
  final seen = <String>{};
  final out = <String>[];
  for (final x in xs) {
    final t = x.trim();
    if (t.isEmpty) continue;
    if (seen.add(t)) out.add(t);
  }
  return out;
}
