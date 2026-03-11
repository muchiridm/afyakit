import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/contacts/services/zoho_contacts_service.dart';
import 'package:afyakit/features/retail/invoices/services/zoho_invoices_service.dart';
import 'package:afyakit/features/retail/payments/zoho/services/zoho_payments_service.dart';

import 'package:afyakit/features/retail/shared/models/zoho_contact.dart';
import 'package:afyakit/features/retail/shared/models/zoho_invoice.dart';
import 'package:afyakit/features/retail/shared/models/zoho_invoice_payment.dart';

/// Strictly invoice-scoped payments list.
/// Uses invoice endpoint under the hood:
/// GET /zoho/v1/payments/invoice/:invoiceId
final invoicePaymentsProvider = FutureProvider.family
    .autoDispose<List<ZohoInvoicePayment>, String>((ref, invoiceId) async {
      final id = invoiceId.trim();
      if (id.isEmpty) return const <ZohoInvoicePayment>[];

      final svc = await ref.read(zohoPaymentsServiceProvider.future);

      // ✅ Backend list is invoice-scoped already…
      final pays = await svc.listInvoicePayments(id);

      // ✅ …but enforce fail-closed scoping anyway.
      // If a row cannot prove it belongs to this invoice, it is excluded.
      final scoped = _onlyForInvoiceFailClosed(pays, id);

      return _dedupeAndSortNewestFirst(scoped);
    });

List<ZohoInvoicePayment> _onlyForInvoiceFailClosed(
  List<ZohoInvoicePayment> xs,
  String invoiceId,
) {
  final inv = invoiceId.trim();
  if (inv.isEmpty) return xs;

  return <ZohoInvoicePayment>[
    for (final p in xs)
      if (_paymentHasInvoice(p, inv)) p,
  ];
}

/// ✅ Fail-closed membership:
/// - if invoiceId matches → OK
/// - else if invoiceIds contains invoiceId → OK
/// - else (no linkage) → NOT OK
bool _paymentHasInvoice(ZohoInvoicePayment p, String invoiceId) {
  final inv = invoiceId.trim();
  if (inv.isEmpty) return false;

  final primary = (p.invoiceId ?? '').trim();
  if (primary.isNotEmpty) return primary == inv;

  // In your UI you already call `p.invoiceIds.contains(...)`,
  // so this is assumed non-null (at least empty list).
  final ids = p.invoiceIds;
  if (ids.isEmpty) return false;

  for (final x in ids) {
    if (x.trim() == inv) return true;
  }
  return false;
}

final invoiceProvider = FutureProvider.family.autoDispose<ZohoInvoice, String>((
  ref,
  invoiceId,
) async {
  final id = invoiceId.trim();
  if (id.isEmpty) throw StateError('invoiceId is empty');

  final svc = await ref.read(zohoInvoicesServiceProvider.future);
  return svc.get(id);
});

final invoiceContactProvider = FutureProvider.family
    .autoDispose<ZohoContact?, String>((ref, invoiceId) async {
      final inv = await ref.watch(invoiceProvider(invoiceId).future);
      final contactId = (inv.customerId ?? '').trim();
      if (contactId.isEmpty) return null;

      return ref.watch(zohoContactProvider(contactId).future);
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

final paymentReceiptVmProvider = FutureProvider.family
    .autoDispose<PaymentReceiptVm, ReceiptKey>((ref, key) async {
      final invoiceId = key.invoiceId.trim();
      final paymentId = key.paymentId.trim();

      if (invoiceId.isEmpty) throw StateError('invoiceId is empty');
      if (paymentId.isEmpty) throw StateError('paymentId is empty');

      // ✅ Speed: invoice + payments can load in parallel.
      final invoiceFuture = ref.watch(invoiceProvider(invoiceId).future);
      final paysFuture = ref.watch(invoicePaymentsProvider(invoiceId).future);

      final invoice = await invoiceFuture;

      // Contact depends on invoice.customerId
      final contactFuture = ref.watch(invoiceContactProvider(invoiceId).future);

      final pays = await paysFuture;
      final contact = await contactFuture;

      // 1) Prefer invoice-scoped list
      final hit = pays.where((p) => p.paymentId.trim() == paymentId).toList();

      ZohoInvoicePayment payment;
      if (hit.isNotEmpty) {
        payment = hit.first;
      } else {
        // 2) Fallback: fetch payment detail & still enforce invoice membership
        final paySvc = await ref.read(zohoPaymentsServiceProvider.future);
        final detail = await paySvc.get(paymentId);

        if (detail == null) {
          throw StateError('Payment not found on this invoice');
        }

        if (!_paymentHasInvoice(detail, invoiceId)) {
          throw StateError('Payment not found on this invoice');
        }

        payment = detail;
      }

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

final zohoContactProvider = FutureProvider.family
    .autoDispose<ZohoContact?, String>((ref, contactId) async {
      final id = contactId.trim();
      if (id.isEmpty) return null;

      final svc = await ref.read(zohoContactsServiceProvider.future);
      return svc.getOrNull(id);
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
