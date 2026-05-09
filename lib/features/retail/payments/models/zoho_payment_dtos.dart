// lib/features/retail/shared/models/zoho_payment_dtos.dart

import 'package:afyakit/shared/utils/utils.dart';
import 'package:afyakit/features/retail/invoices/zoho_invoice.dart';
import 'package:afyakit/features/retail/payments/models/zoho_invoice_payment.dart';

class InvoiceBalanceSummary {
  const InvoiceBalanceSummary({
    required this.invoiceId,
    this.total,
    this.balance,
  });

  final String invoiceId;
  final num? total;
  final num? balance;

  factory InvoiceBalanceSummary.fromJson(JsonMap json) {
    final j = json.cast<String, Object?>();

    return InvoiceBalanceSummary(
      invoiceId: readString(j['invoice_id'] ?? j['id']),
      total: readNumOrNull(j['total']),
      balance: readNumOrNull(j['balance']),
    );
  }
}

class ListInvoicePaymentsResult {
  const ListInvoicePaymentsResult({
    required this.payments,
    required this.invoice,
  });

  final List<ZohoInvoicePayment> payments;
  final InvoiceBalanceSummary invoice;
}

class RecordPaymentResult {
  const RecordPaymentResult({required this.payment, required this.invoice});

  final ZohoInvoicePayment payment;
  final ZohoInvoice invoice;
}
