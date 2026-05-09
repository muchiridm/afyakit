// lib/features/retail/shared/models/zoho_invoice_payment.dart

import 'package:afyakit/shared/utils/utils.dart';

class ZohoInvoicePayment {
  const ZohoInvoicePayment({
    required this.paymentId,
    required this.amount,
    this.invoiceId,
    this.invoiceIds = const <String>[],
    this.contactId,
    this.accountNumber,
    this.date,
    this.mode,
    this.description,
  });

  final String paymentId;
  final num amount;

  /// "Primary" invoice id (best-effort). May be null.
  final String? invoiceId;

  /// ✅ All invoice ids the payment is applied to.
  ///
  /// NOTE:
  /// - Backend currently returns PaymentDTO without allocations arrays,
  ///   so invoiceIds will usually be either:
  ///     - [invoiceId] when invoice_id is present
  ///     - [] when invoice_id is absent (then UI may need to resolve detail)
  final List<String> invoiceIds;

  /// Customer link (Zoho Books contact_id) - typically NOT present in PaymentDTO.
  final String? contactId;

  /// ✅ Optional: your app account number (ONLY if backend injects it)
  ///
  /// IMPORTANT:
  /// - Do NOT infer from reference_number; that is not your identity key anymore.
  final String? accountNumber;

  final DateTime? date;
  final String? mode;
  final String? description;

  factory ZohoInvoicePayment.fromJson(JsonMap json) {
    final j = json.cast<String, Object?>();

    final id = readString(j['payment_id'] ?? j['id']);
    final amount = readNum(j['amount']);

    final date = readDateTime(j['date'] ?? j['payment_date']);

    final invoiceId = _readInvoiceId(j);
    final invoiceIds = _extractInvoiceIds(j, primaryInvoiceId: invoiceId);

    final contactId = _extractContactId(j);

    final mode = readStringOrNull(j['payment_mode'] ?? j['mode']);
    final desc = readStringOrNull(j['description'] ?? j['notes']);

    // ✅ explicit only (aligned with backend)
    final accountNumber = _extractAccountNumberExplicitOnly(j);

    return ZohoInvoicePayment(
      paymentId: id,
      amount: amount,
      invoiceId: invoiceId,
      invoiceIds: invoiceIds,
      contactId: contactId,
      accountNumber: accountNumber,
      date: date,
      mode: mode,
      description: desc,
    );
  }

  // ─────────────────────────────────────────────
  // Invoice ids extraction (tolerant, backend-aligned)
  // ─────────────────────────────────────────────

  static String? _readInvoiceId(Map<String, Object?> j) {
    final direct = readStringOrNull(j['invoice_id'] ?? j['invoiceId']);
    return direct;
  }

  static List<String> _extractInvoiceIds(
    Map<String, Object?> j, {
    required String? primaryInvoiceId,
  }) {
    final out = <String>[];
    final seen = <String>{};

    void addId(String? v) {
      final s = (v ?? '').trim();
      if (s.isEmpty) return;
      if (seen.add(s)) out.add(s);
    }

    // 0) If backend ever emits invoice_ids: ["...","..."]
    final invoiceIdsRaw = j['invoice_ids'] ?? j['invoiceIds'];
    if (invoiceIdsRaw is List) {
      for (final row in invoiceIdsRaw) {
        addId(row?.toString());
      }
    }

    // 1) direct
    addId(primaryInvoiceId);

    // 2) allocations arrays (only present if backend later returns raw Zoho objects)
    _collectStringsFromList(
      j['invoices'],
      keys: const ['invoice_id', 'invoiceId'],
      add: addId,
    );

    _collectStringsFromList(
      j['invoice_payments'],
      keys: const ['invoice_id', 'invoiceId'],
      add: addId,
    );

    // ✅ backend-aligned fallback: if only invoiceId exists, make invoiceIds = [invoiceId]
    if (out.isEmpty &&
        primaryInvoiceId != null &&
        primaryInvoiceId.trim().isNotEmpty) {
      out.add(primaryInvoiceId.trim());
    }

    return List<String>.unmodifiable(out);
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
  // Contact id extraction (kept tolerant)
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

    return null;
  }

  // ─────────────────────────────────────────────
  // Account number extraction (backend-aligned)
  // ─────────────────────────────────────────────

  static String? _extractAccountNumberExplicitOnly(Map<String, Object?> j) {
    return readStringOrNull(
      j['account_number'] ??
          j['accountNumber'] ??
          j['cf_account_number'] ??
          j['cfAccountNumber'],
    );
  }
}
