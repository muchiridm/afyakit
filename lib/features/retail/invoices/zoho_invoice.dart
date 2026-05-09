// lib/features/retail/shared/models/zoho_invoice.dart

import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/shared/utils/utils.dart';

import '../payments/models/zoho_invoice_payment.dart';

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
    this.accountNumber,
    this.currencyCode,
    this.customerId,
    this.customerEmail,
    this.contactPersonIds = const <String>[],
    this.notes,
    this.terms,
    this.dueDate,
    this.balance,
    this.deliveryAddress,
    this.lineItems = const <ZohoInvoiceLineItem>[],
    this.payments = const <ZohoInvoicePayment>[],
  });

  final String invoiceId;
  final String customerName;
  final String status;
  final DateTime? date;
  final num total;

  final String? invoiceNumber;

  /// Your app identity key.
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

  /// Snapshot of chosen delivery address at document time.
  final SalesDocumentAddress? deliveryAddress;

  final List<ZohoInvoiceLineItem> lineItems;
  final List<ZohoInvoicePayment> payments;

  bool get hasRecipients =>
      contactPersonIds.isNotEmpty || (customerEmail ?? '').trim().isNotEmpty;

  bool get hasDeliveryAddress => deliveryAddress?.isUsable == true;

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

    final account = _cleanStringOrNull(
      j['account_number'] ??
          j['accountNumber'] ??
          j['reference_number'] ??
          j['reference'],
    );

    final currency = _cleanStringOrNull(j['currency_code']);

    final customerId = _cleanStringOrNull(j['customer_id']);
    final notes = _cleanStringOrNull(j['notes']);
    final terms = _cleanStringOrNull(j['terms']);

    final deliveryAddress = _parseDeliveryAddress(
      j['delivery_address'] ?? j['deliveryAddress'] ?? j['shipping_address'],
    );

    final lines = _parseLineItems(j['line_items']);
    final pays = _parsePayments(j['payments'] ?? j['payment_details']);

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
      accountNumber: account,
      currencyCode: currency,
      customerId: customerId,
      customerEmail: email,
      contactPersonIds: dedupedCpIds,
      notes: notes,
      terms: terms,
      deliveryAddress: deliveryAddress,
      lineItems: lines,
      payments: pays,
    );
  }

  ZohoInvoice copyWith({
    String? invoiceId,
    String? customerName,
    String? status,
    DateTime? date,
    num? total,
    String? invoiceNumber,
    String? accountNumber,
    String? currencyCode,
    String? customerId,
    String? customerEmail,
    List<String>? contactPersonIds,
    String? notes,
    String? terms,
    DateTime? dueDate,
    num? balance,
    SalesDocumentAddress? deliveryAddress,
    List<ZohoInvoiceLineItem>? lineItems,
    List<ZohoInvoicePayment>? payments,
  }) {
    return ZohoInvoice(
      invoiceId: invoiceId ?? this.invoiceId,
      customerName: customerName ?? this.customerName,
      status: status ?? this.status,
      date: date ?? this.date,
      total: total ?? this.total,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      accountNumber: accountNumber ?? this.accountNumber,
      currencyCode: currencyCode ?? this.currencyCode,
      customerId: customerId ?? this.customerId,
      customerEmail: customerEmail ?? this.customerEmail,
      contactPersonIds: contactPersonIds ?? this.contactPersonIds,
      notes: notes ?? this.notes,
      terms: terms ?? this.terms,
      dueDate: dueDate ?? this.dueDate,
      balance: balance ?? this.balance,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      lineItems: lineItems ?? this.lineItems,
      payments: payments ?? this.payments,
    );
  }
}

SalesDocumentAddress? _parseDeliveryAddress(Object? raw) {
  if (raw is Map<String, dynamic>) {
    final parsed = SalesDocumentAddress.fromJson(raw);
    return parsed.isUsable ? parsed : null;
  }
  if (raw is Map) {
    final parsed = SalesDocumentAddress.fromJson(raw.cast<String, dynamic>());
    return parsed.isUsable ? parsed : null;
  }
  return null;
}

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
    final id1 = readStringOrNull(e)?.trim();
    if (id1 != null && id1.isNotEmpty) {
      out.add(id1);
      continue;
    }

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
