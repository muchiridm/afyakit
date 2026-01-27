// lib/features/retail/sales/payments/controllers/payments_list_controller.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/state/paged_query_controller.dart';

import 'package:afyakit/features/retail/shared/models/zoho_invoice_payment.dart';
import 'package:afyakit/features/retail/payments/zoho/services/zoho_payments_service.dart';
import 'package:afyakit/features/retail/payments/zoho/widgets/payment_detail_screen.dart';

final paymentsListControllerProvider =
    StateNotifierProvider.autoDispose<
      PaymentsListController,
      PagedQueryState<ZohoInvoicePayment>
    >((ref) {
      final ctl = PaymentsListController(ref);
      ctl.refresh(reset: true);
      return ctl;
    });

class PaymentsListController extends PagedQueryController<ZohoInvoicePayment> {
  PaymentsListController(this._ref);

  final Ref _ref;

  @override
  Future<PageResult<ZohoInvoicePayment>> fetchPage({
    required String? q,
    required int page,
    required int limit,
  }) async {
    final svc = await _ref.read(zohoPaymentsServiceProvider.future);

    final items = await svc.list(perPage: limit, page: page);

    final hasMore = items.length == limit;
    return PageResult(items: items, hasMore: hasMore);
  }

  // ─────────────────────────────────────────────
  // UI action: open receipt screen for a payment
  // ─────────────────────────────────────────────

  Future<void> openPayment(BuildContext context, ZohoInvoicePayment p) async {
    final paymentId = p.paymentId.trim();
    if (paymentId.isEmpty) {
      _snack(context, 'Payment id is missing');
      return;
    }

    // 1) Use invoiceId if already present on list payload
    var invoiceId = (p.invoiceId ?? '').trim();

    // 2) Otherwise resolve via backend
    if (invoiceId.isEmpty) {
      try {
        final svc = await _ref.read(zohoPaymentsServiceProvider.future);
        final resolved = await svc.resolveInvoiceIdForPayment(paymentId);
        invoiceId = (resolved ?? '').trim();
      } catch (_) {
        // ignore
      }
    }

    if (invoiceId.isEmpty) {
      _snack(context, 'Payment has no invoice attached');
      return;
    }

    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentDetailScreen(
          invoiceId: invoiceId,
          paymentId: paymentId,

          // Optional context if your list model carries them later.
          // Safe defaults for now:
          currencyCode: 'KES',
        ),
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    final m = msg.trim();
    if (m.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }
}
