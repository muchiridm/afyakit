import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/invoices/models/zoho_invoice.dart';
import 'package:afyakit/features/retail/invoices/services/zoho_invoices_service.dart';
import 'package:afyakit/features/retail/payments/models/zoho_invoice_payment.dart';
import 'package:afyakit/features/retail/payments/services/zoho_payments_service.dart';

/// Payments belonging to a specific invoice.
final invoicePaymentsProvider = FutureProvider.family
    .autoDispose<List<ZohoInvoicePayment>, String>((ref, invoiceId) async {
      final id = invoiceId.trim();
      if (id.isEmpty) return const <ZohoInvoicePayment>[];

      final service = await ref.read(zohoPaymentsServiceProvider.future);
      final payments = await service.listInvoicePayments(id);

      return _dedupeAndSortNewestFirst(
        payments.where((payment) => _paymentHasInvoice(payment, id)).toList(),
      );
    });

/// Invoice detail.
final invoiceProvider = FutureProvider.family.autoDispose<ZohoInvoice, String>((
  ref,
  invoiceId,
) async {
  final id = invoiceId.trim();
  if (id.isEmpty) throw StateError('invoiceId is empty');

  final service = await ref.read(zohoInvoicesServiceProvider.future);
  return service.get(id);
});

typedef ReceiptKey = ({String invoiceId, String paymentId});

class PaymentReceiptVm {
  const PaymentReceiptVm({
    required this.invoice,
    required this.payment,
    required this.otherPayments,
  });

  final ZohoInvoice invoice;
  final ZohoInvoicePayment payment;
  final List<ZohoInvoicePayment> otherPayments;
}

/// Receipt detail assembled from the invoice and its verified payments.
final paymentReceiptVmProvider = FutureProvider.family
    .autoDispose<PaymentReceiptVm, ReceiptKey>((ref, key) async {
      final invoiceId = key.invoiceId.trim();
      final paymentId = key.paymentId.trim();

      if (invoiceId.isEmpty) {
        throw StateError('invoiceId is empty');
      }
      if (paymentId.isEmpty) {
        throw StateError('paymentId is empty');
      }

      // Load independent resources concurrently.
      final invoiceFuture = ref.watch(invoiceProvider(invoiceId).future);
      final paymentsFuture = ref.watch(
        invoicePaymentsProvider(invoiceId).future,
      );

      final invoice = await invoiceFuture;
      final payments = await paymentsFuture;

      ZohoInvoicePayment? selected;

      for (final payment in payments) {
        if (payment.paymentId.trim() == paymentId) {
          selected = payment;
          break;
        }
      }

      if (selected == null) {
        final service = await ref.read(zohoPaymentsServiceProvider.future);

        final detail = await service.get(paymentId);

        if (detail == null || !_paymentHasInvoice(detail, invoiceId)) {
          throw StateError('Payment not found on this invoice');
        }

        selected = detail;
      }

      final others = <ZohoInvoicePayment>[
        for (final payment in payments)
          if (payment.paymentId.trim() != paymentId) payment,
      ];

      return PaymentReceiptVm(
        invoice: invoice,
        payment: selected,
        otherPayments: List<ZohoInvoicePayment>.unmodifiable(others),
      );
    });

/// A payment must explicitly reference the requested invoice.
///
/// This is a defensive consistency check, not an authorisation boundary.
bool _paymentHasInvoice(ZohoInvoicePayment payment, String invoiceId) {
  final id = invoiceId.trim();
  if (id.isEmpty) return false;

  final primaryId = (payment.invoiceId ?? '').trim();

  if (primaryId.isNotEmpty && primaryId == id) {
    return true;
  }

  return payment.invoiceIds.any((linkedId) => linkedId.trim() == id);
}

List<ZohoInvoicePayment> _dedupeAndSortNewestFirst(
  List<ZohoInvoicePayment> payments,
) {
  final seen = <String>{};
  final result = <ZohoInvoicePayment>[];

  for (final payment in payments) {
    final id = payment.paymentId.trim();

    if (id.isEmpty || !seen.add(id)) continue;

    result.add(payment);
  }

  result.sort(_sortNewestFirst);

  return List<ZohoInvoicePayment>.unmodifiable(result);
}

int _sortNewestFirst(ZohoInvoicePayment a, ZohoInvoicePayment b) {
  final aDate = a.date;
  final bDate = b.date;

  if (aDate != null && bDate != null) {
    final comparison = bDate.compareTo(aDate);
    if (comparison != 0) return comparison;
  } else if (aDate == null && bDate != null) {
    return 1;
  } else if (aDate != null && bDate == null) {
    return -1;
  }

  return b.paymentId.compareTo(a.paymentId);
}
