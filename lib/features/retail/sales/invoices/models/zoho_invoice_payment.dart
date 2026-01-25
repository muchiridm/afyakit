// lib/features/retail/sales/invoices/models/zoho_invoice_payment.dart

typedef JsonMap = Map<String, dynamic>;

class ZohoInvoicePayment {
  const ZohoInvoicePayment({
    required this.paymentId,
    required this.amount,
    this.date,
    this.mode,
    this.referenceNumber,
    this.description,
  });

  final String paymentId;
  final num amount;

  final DateTime? date;
  final String? mode;
  final String? referenceNumber;
  final String? description;

  factory ZohoInvoicePayment.fromJson(JsonMap j) {
    final id = (j['payment_id'] ?? j['id'] ?? '').toString().trim();

    final amtRaw = j['amount'];
    final amount = amtRaw is num ? amtRaw : num.tryParse('$amtRaw') ?? 0;

    DateTime? date;
    final rawDate = (j['date'] ?? j['payment_date'])?.toString().trim();
    if (rawDate != null && rawDate.isNotEmpty) {
      date = DateTime.tryParse(rawDate);
    }

    final modeRaw = (j['payment_mode'] ?? j['mode'] ?? '').toString().trim();

    final refRaw = (j['reference_number'] ?? j['reference'] ?? '')
        .toString()
        .trim();

    final descRaw = (j['description'] ?? j['notes'] ?? '').toString().trim();

    return ZohoInvoicePayment(
      paymentId: id,
      amount: amount,
      date: date,
      mode: modeRaw.isEmpty ? null : modeRaw,
      referenceNumber: refRaw.isEmpty ? null : refRaw,
      description: descRaw.isEmpty ? null : descRaw,
    );
  }
}
