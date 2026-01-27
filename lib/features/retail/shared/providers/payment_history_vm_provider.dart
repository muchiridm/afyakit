import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/payments/zoho/controllers/payment_controller.dart';
import 'package:afyakit/features/retail/payments/zoho/controllers/payment_state.dart';
import 'package:afyakit/features/retail/shared/models/zoho_invoice_payment.dart';

/// Key used to build a payment history view for a single invoice.
///
/// Using a record keeps call-sites clean:
/// matchedPaymentHistoryVmProvider((invoiceId: '...', excludePaymentId: '...', maxRows: 8))
typedef PaymentHistoryVmKey = ({
  String invoiceId,
  String? excludePaymentId,
  int? maxRows,
});

@immutable
class PaymentHistoryVm {
  const PaymentHistoryVm({
    required this.invoiceId,
    required this.busy,
    required this.loading,
    required this.error,
    required this.allRows,
    required this.visibleRows,
  });

  final String invoiceId;

  /// “Busy” in your app means any mutation is happening (saving/deleting/etc).
  final bool busy;

  /// Loading list from Zoho.
  final bool loading;

  /// Any controller error string (best-effort).
  final String? error;

  /// All rows (after dedupe/filter/sort, before maxRows).
  final List<ZohoInvoicePayment> allRows;

  /// Rows to show in UI (maxRows applied).
  final List<ZohoInvoicePayment> visibleRows;

  bool get isEmpty => allRows.isEmpty;
  int get totalCount => allRows.length;

  static PaymentHistoryVm fromState(
    PaymentState s, {
    required String invoiceId,
    String? excludePaymentId,
    int? maxRows,
  }) {
    final rows = _prepareRows(
      payments: s.payments,
      excludePaymentId: excludePaymentId,
    );

    final visible = _takeMax(rows, maxRows);

    return PaymentHistoryVm(
      invoiceId: invoiceId,
      busy: s.busy,
      loading: s.loadingPayments,
      error: (s.error ?? '').trim().isEmpty ? null : s.error,
      allRows: List<ZohoInvoicePayment>.unmodifiable(rows),
      visibleRows: List<ZohoInvoicePayment>.unmodifiable(visible),
    );
  }

  // ─────────────────────────────
  // Pure helpers
  // ─────────────────────────────

  static List<ZohoInvoicePayment> _prepareRows({
    required List<ZohoInvoicePayment> payments,
    String? excludePaymentId,
  }) {
    // 1) Dedupe by paymentId
    final out = <ZohoInvoicePayment>[];
    final seen = <String>{};

    for (final p in payments) {
      final pid = p.paymentId.trim();
      if (pid.isEmpty) continue;
      if (!seen.add(pid)) continue;
      out.add(p);
    }

    // 2) Exclude one row (e.g. currently viewed payment on receipt screen)
    final ex = (excludePaymentId ?? '').trim();
    if (ex.isNotEmpty) {
      out.removeWhere((p) => p.paymentId.trim() == ex);
    }

    // 3) Sort newest first (date desc; null dates last; tie-breaker by id)
    out.sort(_sortNewestFirst);

    return out;
  }

  static List<ZohoInvoicePayment> _takeMax(
    List<ZohoInvoicePayment> xs,
    int? maxRows,
  ) {
    if (maxRows == null || maxRows <= 0) return xs;
    if (xs.length <= maxRows) return xs;
    return xs.take(maxRows).toList();
  }

  static int _sortNewestFirst(ZohoInvoicePayment a, ZohoInvoicePayment b) {
    final ad = a.date;
    final bd = b.date;

    if (ad != null && bd != null) {
      final c = bd.compareTo(ad);
      if (c != 0) return c;
    } else if (ad == null && bd != null) {
      return 1; // a after b
    } else if (ad != null && bd == null) {
      return -1; // a before b
    }

    // tie-breaker
    return b.paymentId.compareTo(a.paymentId);
  }
}

/// UI-facing provider: gives the widget everything it needs to render.
///
/// IMPORTANT:
/// This provider ONLY uses `paymentControllerProvider(invoiceId)`,
/// so it will ONLY ever show payments for that invoice.
/// (No global payments list, no cross-invoice leakage.)
final paymentHistoryVmProvider =
    Provider.family<PaymentHistoryVm, PaymentHistoryVmKey>((ref, key) {
      final invoiceId = key.invoiceId.trim();
      final exclude = (key.excludePaymentId ?? '').trim();
      final maxRows = key.maxRows;

      if (invoiceId.isEmpty) {
        return const PaymentHistoryVm(
          invoiceId: '',
          busy: false,
          loading: false,
          error: 'invoiceId is empty',
          allRows: <ZohoInvoicePayment>[],
          visibleRows: <ZohoInvoicePayment>[],
        );
      }

      final PaymentState s = ref.watch(paymentControllerProvider(invoiceId));

      return PaymentHistoryVm.fromState(
        s,
        invoiceId: invoiceId,
        excludePaymentId: exclude.isEmpty ? null : exclude,
        maxRows: maxRows,
      );
    });
