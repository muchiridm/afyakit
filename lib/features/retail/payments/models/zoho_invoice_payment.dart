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
    this.reference,
    this.invoiceNumber,
    this.customerId,
    this.customerName,
    this.patientNo,
    this.patientName,
  });

  final String paymentId;
  final num amount;

  /// Primary invoice id, best-effort.
  final String? invoiceId;

  /// All invoice ids this payment is applied to.
  final List<String> invoiceIds;

  /// Zoho contact/customer id.
  final String? contactId;

  /// App-level account/member number, only if backend injects it.
  final String? accountNumber;

  final DateTime? date;
  final String? mode;
  final String? description;

  /// Payment reference / M-Pesa receipt / bank reference.
  final String? reference;

  /// Hydrated invoice/customer context.
  final String? invoiceNumber;
  final String? customerId;
  final String? customerName;

  /// Hydrated clinical context.
  final String? patientNo;
  final String? patientName;

  factory ZohoInvoicePayment.fromJson(JsonMap json) {
    final j = json.cast<String, Object?>();

    final invoiceId = _readInvoiceId(j);

    return ZohoInvoicePayment(
      paymentId: readString(j['payment_id'] ?? j['id']),
      amount: readNum(j['amount']),
      invoiceId: invoiceId,
      invoiceIds: _extractInvoiceIds(j, primaryInvoiceId: invoiceId),
      contactId: _extractContactId(j),
      accountNumber: _extractAccountNumberExplicitOnly(j),
      date: readDateTime(j['date'] ?? j['payment_date']),
      mode: readStringOrNull(j['payment_mode'] ?? j['mode']),
      description: readStringOrNull(j['description'] ?? j['notes']),
      reference: readStringOrNull(
        j['reference'] ?? j['reference_number'] ?? j['referenceNumber'],
      ),
      invoiceNumber: readStringOrNull(
        j['invoice_number'] ?? j['invoiceNumber'],
      ),
      customerId: readStringOrNull(j['customer_id'] ?? j['customerId']),
      customerName: readStringOrNull(j['customer_name'] ?? j['customerName']),
      patientNo: readStringOrNull(j['patient_no'] ?? j['patientNo']),
      patientName: readStringOrNull(j['patient_name'] ?? j['patientName']),
    );
  }

  static String? _readInvoiceId(Map<String, Object?> j) {
    return readStringOrNull(j['invoice_id'] ?? j['invoiceId']);
  }

  static List<String> _extractInvoiceIds(
    Map<String, Object?> j, {
    required String? primaryInvoiceId,
  }) {
    final out = <String>[];
    final seen = <String>{};

    void addId(String? value) {
      final id = (value ?? '').trim();
      if (id.isEmpty) return;
      if (seen.add(id)) out.add(id);
    }

    final invoiceIdsRaw = j['invoice_ids'] ?? j['invoiceIds'];

    if (invoiceIdsRaw is List) {
      for (final row in invoiceIdsRaw) {
        addId(row?.toString());
      }
    }

    addId(primaryInvoiceId);

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

    return List<String>.unmodifiable(out);
  }

  static void _collectStringsFromList(
    Object? value, {
    required List<String> keys,
    required void Function(String? value) add,
  }) {
    if (value is! List) return;

    for (final row in value) {
      if (!isRecord(row)) continue;

      final m = (row as Map).cast<String, Object?>();

      for (final key in keys) {
        add(readStringOrNull(m[key]));
      }
    }
  }

  static String? _extractContactId(Map<String, Object?> j) {
    final direct = readStringOrNull(j['contact_id'] ?? j['contactId']);
    if (direct != null) return direct;

    final customerId = readStringOrNull(j['customer_id'] ?? j['customerId']);
    if (customerId != null) return customerId;

    final customer = j['customer'];

    if (isRecord(customer)) {
      final m = (customer as Map).cast<String, Object?>();
      final value = readStringOrNull(m['contact_id'] ?? m['contactId']);
      if (value != null) return value;
    }

    final contact = j['contact'];

    if (isRecord(contact)) {
      final m = (contact as Map).cast<String, Object?>();
      final value = readStringOrNull(m['contact_id'] ?? m['contactId']);
      if (value != null) return value;
    }

    return null;
  }

  static String? _extractAccountNumberExplicitOnly(Map<String, Object?> j) {
    return readStringOrNull(
      j['account_number'] ??
          j['accountNumber'] ??
          j['cf_account_number'] ??
          j['cfAccountNumber'],
    );
  }
}
