// lib/features/retail/shared/models/zoho_invoice_payment.dart

import 'package:afyakit/shared/utils/utils.dart';

class ZohoInvoicePayment {
  const ZohoInvoicePayment({
    required this.paymentId,
    required this.amount,
    this.invoiceId,
    this.invoiceIds = const <String>[],
    this.contactId,
    this.date,
    this.mode,
    this.referenceNumber,
    this.description,
  });

  final String paymentId;
  final num amount;

  /// "Primary" invoice id (best-effort). May be null or just the first match.
  final String? invoiceId;

  /// ✅ All invoice ids the payment is applied to (reliable for filtering)
  final List<String> invoiceIds;

  /// Customer link (Zoho Books contact_id)
  final String? contactId;

  final DateTime? date;
  final String? mode;
  final String? referenceNumber;
  final String? description;

  factory ZohoInvoicePayment.fromJson(JsonMap json) {
    final j = json.cast<String, Object?>();

    final id = readString(j['payment_id'] ?? j['id']);
    final amount = readNum(j['amount']);

    final date = readDateTime(j['date'] ?? j['payment_date']);

    final invoiceIds = _extractInvoiceIds(j);
    final invoiceId = _extractPrimaryInvoiceId(j, invoiceIds);

    final contactId = _extractContactId(j);

    final mode = readStringOrNull(j['payment_mode'] ?? j['mode']);
    final ref = readStringOrNull(j['reference_number'] ?? j['reference']);
    final desc = readStringOrNull(j['description'] ?? j['notes']);

    return ZohoInvoicePayment(
      paymentId: id,
      amount: amount,
      invoiceId: invoiceId,
      invoiceIds: invoiceIds,
      contactId: contactId,
      date: date,
      mode: mode,
      referenceNumber: ref,
      description: desc,
    );
  }

  // ─────────────────────────────────────────────
  // Invoice ids extraction (ALL of them)
  // ─────────────────────────────────────────────

  static List<String> _extractInvoiceIds(Map<String, Object?> j) {
    final out = <String>[];
    final seen = <String>{};

    void addId(String? v) {
      final s = (v ?? '').trim();
      if (s.isEmpty) return;
      if (seen.add(s)) out.add(s);
    }

    // direct
    addId(readStringOrNull(j['invoice_id'] ?? j['invoiceId']));

    // invoices: [{ invoice_id }]
    _collectStringsFromList(
      j['invoices'],
      keys: const ['invoice_id', 'invoiceId'],
      add: addId,
    );

    // invoice_payments: [{ invoice_id }]
    _collectStringsFromList(
      j['invoice_payments'],
      keys: const ['invoice_id', 'invoiceId'],
      add: addId,
    );

    return List<String>.unmodifiable(out);
  }

  static String? _extractPrimaryInvoiceId(
    Map<String, Object?> j,
    List<String> invoiceIds,
  ) {
    // If Zoho gave direct, prefer it.
    final direct = readStringOrNull(j['invoice_id'] ?? j['invoiceId']);
    if (direct != null) return direct;

    // Otherwise, just use the first extracted id (if any).
    return invoiceIds.isEmpty ? null : invoiceIds.first;
  }

  static void _collectStringsFromList(
    Object? v, {
    required List<String> keys,
    required void Function(String? s) add,
  }) {
    if (v is! List) return;

    for (final row in v) {
      if (!isRecord(row)) continue;
      final m = (row as Map).cast<String, Object?>();
      for (final k in keys) {
        add(readStringOrNull(m[k]));
      }
    }
  }

  // ─────────────────────────────────────────────
  // Contact id extraction
  // ─────────────────────────────────────────────

  static String? _extractContactId(Map<String, Object?> j) {
    final direct = readStringOrNull(j['contact_id'] ?? j['contactId']);
    if (direct != null) return direct;

    final cust = readStringOrNull(j['customer_id'] ?? j['customerId']);
    if (cust != null) return cust;

    final customer = j['customer'];
    if (isRecord(customer)) {
      final m = (customer as Map).cast<String, Object?>();
      final v = readStringOrNull(m['contact_id'] ?? m['contactId']);
      if (v != null) return v;
    }

    final contact = j['contact'];
    if (isRecord(contact)) {
      final m = (contact as Map).cast<String, Object?>();
      final v = readStringOrNull(m['contact_id'] ?? m['contactId']);
      if (v != null) return v;
    }

    // Sometimes present inside allocations
    String? fromList(Object? list) {
      if (list is! List) return null;
      for (final row in list) {
        if (!isRecord(row)) continue;
        final m = (row as Map).cast<String, Object?>();
        final v = readStringOrNull(
          m['contact_id'] ??
              m['contactId'] ??
              m['customer_id'] ??
              m['customerId'],
        );
        if (v != null) return v;
      }
      return null;
    }

    return fromList(j['invoices']) ?? fromList(j['invoice_payments']);
  }
}
