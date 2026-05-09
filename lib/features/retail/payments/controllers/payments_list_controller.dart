// lib/features/retail/payments/zoho/controllers/payments_list_controller.dart

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/state/paged_query_controller.dart';
import 'package:afyakit/features/retail/payments/models/zoho_invoice_payment.dart';
import 'package:afyakit/features/retail/payments/services/zoho_payments_service.dart';
import 'package:afyakit/features/retail/payments/widgets/payment_detail_screen.dart';

final paymentsListControllerProvider = StateNotifierProvider.autoDispose
    .family<
      PaymentsListController,
      PagedQueryState<ZohoInvoicePayment>,
      RetailDocScope
    >((ref, scope) {
      final ctl = PaymentsListController(ref, scope: scope);
      ctl.refresh(reset: true);
      return ctl;
    });

class PaymentsListController extends PagedQueryController<ZohoInvoicePayment> {
  PaymentsListController(this._ref, {required this.scope});

  final Ref _ref;
  final RetailDocScope scope;

  bool get _isMine => scope == RetailDocScope.mine;

  @override
  Future<PageResult<ZohoInvoicePayment>> fetchPage({
    required String? q,
    required int page,
    required int limit,
  }) async {
    final svc = await _ref.read(zohoPaymentsServiceProvider.future);

    // Member scope must be hard-filtered by accountNumber.
    // If missing: fail closed (return empty).
    final me = _ref.read(currentUserValueProvider);
    final acct = (me?.accountNumber ?? '').trim();

    if (_isMine && acct.isEmpty) {
      return const PageResult(items: <ZohoInvoicePayment>[], hasMore: false);
    }

    final items = await svc.list(
      perPage: limit,
      page: page,
      q: (q ?? '').trim().isEmpty ? null : q!.trim(),
      accountNumber: _isMine ? acct : null,
    );

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
          currencyCode:
              'KES', // safe default; override later if your model carries it
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
