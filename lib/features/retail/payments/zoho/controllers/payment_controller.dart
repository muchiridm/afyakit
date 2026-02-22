// lib/features/retail/payments/zoho/controllers/payment_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/payments/zoho/controllers/payment_state.dart';
import 'package:afyakit/features/retail/shared/models/zoho_payment_draft.dart';
import 'package:afyakit/features/retail/shared/models/zoho_invoice_payment.dart';
import 'package:afyakit/features/retail/payments/zoho/services/zoho_payments_service.dart';

import 'package:afyakit/shared/services/snack_service.dart';

final paymentControllerProvider =
    StateNotifierProvider.family<PaymentController, PaymentState, String>(
      (ref, invoiceId) => PaymentController(ref, invoiceId),
    );

class PaymentController extends StateNotifier<PaymentState> {
  PaymentController(this._ref, String invoiceId)
    : super(
        PaymentState(
          invoiceId: invoiceId.trim(),
          paymentDraft: ZohoPaymentDraft.today(invoiceId: invoiceId.trim()),
        ),
      ) {
    final id = (state.invoiceId ?? '').trim();
    if (id.isNotEmpty) {
      // fire-and-forget for UX
      // ignore: discarded_futures
      load();
    }
  }

  final Ref _ref;

  bool get _busy => state.busy;

  String get invoiceId => (state.invoiceId ?? '').trim();

  // ───────────────────────── Load / Refresh ─────────────────────────

  Future<void> load() async {
    final id = invoiceId;
    if (id.isEmpty || _busy) return;

    state = state.copyWith(
      loadingPayments: true,
      clearError: true,
      clearPayments: true,
      clearInvoiceSummary: true,
      clearEditingPaymentId: true,
      paymentDraft: ZohoPaymentDraft.today(invoiceId: id),
    );

    try {
      final svc = await _ref.read(zohoPaymentsServiceProvider.future);
      final payRes = await svc.listInvoicePaymentsWithBalance(id);

      state = state.copyWith(
        loadingPayments: false,
        payments: payRes.payments,
        invoiceSummary: payRes.invoice,
      );
    } catch (e) {
      state = state.copyWith(loadingPayments: false, error: _err(e));
      SnackService.showError('Failed to load payments');
    }
  }

  Future<void> refresh() async {
    final id = invoiceId;
    if (id.isEmpty || _busy) return;

    state = state.copyWith(loadingPayments: true, clearError: true);

    try {
      final svc = await _ref.read(zohoPaymentsServiceProvider.future);
      final payRes = await svc.listInvoicePaymentsWithBalance(id);

      state = state.copyWith(
        loadingPayments: false,
        payments: payRes.payments,
        invoiceSummary: payRes.invoice,
      );
    } catch (e) {
      state = state.copyWith(loadingPayments: false, error: _err(e));
      SnackService.showError('Failed to load payments');
    }
  }

  // ───────────────────────── Draft ─────────────────────────

  void startNewPayment() {
    if (_busy) return;

    final invId = invoiceId;

    state = state.copyWith(
      clearEditingPaymentId: true,
      paymentDraft: ZohoPaymentDraft.today(invoiceId: invId),
      clearError: true,
    );
  }

  void startEditPayment(ZohoInvoicePayment p) {
    if (_busy) return;

    final pid = p.paymentId.trim();
    if (pid.isEmpty) return;

    final invId = invoiceId;

    final dt = p.date ?? DateTime.now();
    final dateOnly = DateTime(dt.year, dt.month, dt.day);

    state = state.copyWith(
      editingPaymentId: pid,
      paymentDraft: ZohoPaymentDraft(
        invoiceId: invId,
        amount: p.amount,
        date: dateOnly,
        mode: p.mode,
        description: p.description,
        accountId: null, // Zoho often doesn't return it reliably
      ),
      clearError: true,
    );
  }

  void cancelPaymentEdit() {
    if (_busy) return;
    startNewPayment();
    SnackService.showSuccess('Payment edit cancelled');
  }

  void patchDraft({
    num? amount,
    DateTime? date,
    String? mode,
    bool clearMode = false,
    String? description,
    bool clearDescription = false,
    String? accountId,
    bool clearAccountId = false,
  }) {
    if (_busy) return;

    final d = state.paymentDraft;

    final nextDate = date == null
        ? null
        : DateTime(date.year, date.month, date.day);

    state = state.copyWith(
      clearError: true,
      paymentDraft: d.copyWith(
        // keep invoiceId unchanged here
        amount: amount ?? d.amount,
        date: nextDate ?? d.date,
        mode: clearMode ? null : (mode ?? d.mode),
        description: clearDescription ? null : (description ?? d.description),
        accountId: clearAccountId ? null : (accountId ?? d.accountId),
      ),
    );
  }

  // ───────────────────────── Actions ─────────────────────────

  Future<bool> savePayment() async {
    if (_busy) return false;

    final invId = invoiceId;
    if (invId.isEmpty) {
      SnackService.showError('Missing invoice id');
      return false;
    }

    // Force invoiceId into the draft right before POST/PUT
    final draft = state.paymentDraft.copyWith(invoiceId: invId).withDateOnly();

    if (!_validateDraft(draft)) return false;

    state = state.copyWith(savingPayment: true, clearError: true);

    try {
      final svc = await _ref.read(zohoPaymentsServiceProvider.future);
      final editingId = (state.editingPaymentId ?? '').trim();

      if (editingId.isNotEmpty) {
        await svc.update(editingId, draft);
        SnackService.showSuccess('Payment updated');
      } else {
        await svc.create(draft);
        SnackService.showSuccess('Payment recorded');
      }

      // Always refresh list+balance from invoice-scoped endpoint
      final payRes = await svc.listInvoicePaymentsWithBalance(invId);

      state = state.copyWith(
        savingPayment: false,
        payments: payRes.payments,
        invoiceSummary: payRes.invoice,
        clearEditingPaymentId: true,
        paymentDraft: ZohoPaymentDraft.today(invoiceId: invId),
      );

      return true;
    } catch (e) {
      state = state.copyWith(savingPayment: false, error: _err(e));
      SnackService.showError('Failed to save payment');
      return false;
    }
  }

  Future<bool> deletePayment(String paymentId) async {
    if (_busy) return false;

    final pid = paymentId.trim();
    if (pid.isEmpty) return false;

    final invId = invoiceId;
    if (invId.isEmpty) return false;

    state = state.copyWith(deletingPayment: true, clearError: true);

    try {
      final svc = await _ref.read(zohoPaymentsServiceProvider.future);

      await svc.remove(pid);

      final payRes = await svc.listInvoicePaymentsWithBalance(invId);

      final wasEditingThis = (state.editingPaymentId ?? '').trim() == pid;

      state = state.copyWith(
        deletingPayment: false,
        payments: payRes.payments,
        invoiceSummary: payRes.invoice,
        editingPaymentId: wasEditingThis ? null : state.editingPaymentId,
        paymentDraft: wasEditingThis
            ? ZohoPaymentDraft.today(invoiceId: invId)
            : state.paymentDraft,
      );

      SnackService.showSuccess('Payment deleted');
      return true;
    } catch (e) {
      state = state.copyWith(deletingPayment: false, error: _err(e));
      SnackService.showError('Failed to delete payment');
      return false;
    }
  }

  // ───────────────────────── Validation ─────────────────────────

  bool _validateDraft(ZohoPaymentDraft d) {
    final inv = d.invoiceId.trim();
    if (inv.isEmpty) {
      SnackService.showError('Missing invoice id');
      return false;
    }

    final amt = d.amount;
    if (amt.isNaN || amt.isInfinite || amt <= 0) {
      SnackService.showError('Amount must be greater than 0');
      return false;
    }

    final dt = d.date;
    if (dt.year < 2000) {
      SnackService.showError('Invalid payment date');
      return false;
    }

    return true;
  }

  static String _err(Object e) {
    final s = e.toString().trim();
    return s.isEmpty ? 'Unknown error' : s;
  }
}
