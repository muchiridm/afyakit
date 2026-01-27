// lib/features/retail/shared/providers/payment_receipt_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/contacts/services/zoho_contacts_service.dart';
import 'package:afyakit/features/retail/invoices/services/zoho_invoices_service.dart';
import 'package:afyakit/features/retail/payments/zoho/services/zoho_payments_service.dart';

import 'package:afyakit/features/retail/shared/models/zoho_contact.dart';
import 'package:afyakit/features/retail/shared/models/zoho_invoice.dart';
import 'package:afyakit/features/retail/shared/models/zoho_invoice_payment.dart';

/// Strictly invoice-scoped payments list.
/// Uses /payments?invoice_id=... under the hood.
final invoicePaymentsProvider =
    FutureProvider.family<List<ZohoInvoicePayment>, String>((
      ref,
      invoiceId,
    ) async {
      final id = invoiceId.trim();
      if (id.isEmpty) throw StateError('invoiceId is empty');

      final svc = await ref.read(zohoPaymentsServiceProvider.future);

      // This *should* already be invoice-scoped…
      final pays = await svc.listInvoicePayments(id);

      // ✅ …but we enforce it anyway, because backend/Zoho payloads can be sloppy.
      final scoped = _onlyForInvoice(pays, id);

      return _dedupeAndSortNewestFirst(scoped);
    });

List<ZohoInvoicePayment> _onlyForInvoice(
  List<ZohoInvoicePayment> xs,
  String invoiceId,
) {
  final inv = invoiceId.trim();
  if (inv.isEmpty) return xs;

  return <ZohoInvoicePayment>[
    for (final p in xs)
      if ((p.invoiceId ?? '').trim() == inv || p.invoiceIds.contains(inv)) p,
  ];
}

final invoiceProvider = FutureProvider.family<ZohoInvoice, String>((
  ref,
  invoiceId,
) async {
  final id = invoiceId.trim();
  if (id.isEmpty) throw StateError('invoiceId is empty');

  final svc = await ref.read(zohoInvoicesServiceProvider.future);
  return svc.get(id);
});

final invoiceContactProvider = FutureProvider.family<ZohoContact?, String>((
  ref,
  invoiceId,
) async {
  final inv = await ref.watch(invoiceProvider(invoiceId).future);

  final contactId = (inv.customerId ?? '').trim();
  if (contactId.isEmpty) return null;

  final svc = await ref.read(zohoContactsServiceProvider.future);
  return svc.getOrNull(contactId);
});

typedef ReceiptKey = ({String invoiceId, String paymentId});

class PaymentReceiptVm {
  const PaymentReceiptVm({
    required this.invoice,
    required this.contact,
    required this.payment,
    required this.otherPayments,
  });

  final ZohoInvoice invoice;
  final ZohoContact? contact;
  final ZohoInvoicePayment payment;
  final List<ZohoInvoicePayment> otherPayments;
}

final paymentReceiptVmProvider =
    FutureProvider.family<PaymentReceiptVm, ReceiptKey>((ref, key) async {
      final invoiceId = key.invoiceId.trim();
      final paymentId = key.paymentId.trim();

      if (invoiceId.isEmpty) throw StateError('invoiceId is empty');
      if (paymentId.isEmpty) throw StateError('paymentId is empty');

      final invoice = await ref.watch(invoiceProvider(invoiceId).future);
      final contact = await ref.watch(invoiceContactProvider(invoiceId).future);

      final pays = await ref.watch(invoicePaymentsProvider(invoiceId).future);

      final payment = pays.firstWhere(
        (p) => p.paymentId.trim() == paymentId,
        orElse: () => throw StateError('Payment not found on this invoice'),
      );

      final others = <ZohoInvoicePayment>[
        for (final p in pays)
          if (p.paymentId.trim() != paymentId) p,
      ];

      return PaymentReceiptVm(
        invoice: invoice,
        contact: contact,
        payment: payment,
        otherPayments: List<ZohoInvoicePayment>.unmodifiable(others),
      );
    });

List<ZohoInvoicePayment> _dedupeAndSortNewestFirst(
  List<ZohoInvoicePayment> xs,
) {
  final out = <ZohoInvoicePayment>[];
  final seen = <String>{};

  for (final p in xs) {
    final pid = p.paymentId.trim();
    if (pid.isEmpty) continue;
    if (!seen.add(pid)) continue;
    out.add(p);
  }

  out.sort(_sortNewestFirst);
  return List<ZohoInvoicePayment>.unmodifiable(out);
}

int _sortNewestFirst(ZohoInvoicePayment a, ZohoInvoicePayment b) {
  final ad = a.date;
  final bd = b.date;

  if (ad != null && bd != null) {
    final c = bd.compareTo(ad);
    if (c != 0) return c;
  } else if (ad == null && bd != null) {
    return 1;
  } else if (ad != null && bd == null) {
    return -1;
  }

  return b.paymentId.compareTo(a.paymentId);
}
