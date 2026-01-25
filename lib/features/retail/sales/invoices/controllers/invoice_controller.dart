// lib/features/retail/sales/invoices/controllers/invoice_controller.dart

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/sales/invoices/controllers/invoice_state.dart';
import 'package:afyakit/features/retail/sales/invoices/models/payment_draft.dart';
import 'package:afyakit/features/retail/sales/invoices/models/zoho_invoice_payment.dart';
import 'package:afyakit/features/retail/sales/invoices/services/zoho_invoices_service.dart';

import 'package:afyakit/shared/services/snack_service.dart';

final invoiceControllerProvider =
    StateNotifierProvider<InvoiceController, InvoiceState>(
      (ref) => InvoiceController(ref),
    );

class InvoiceController extends StateNotifier<InvoiceState> {
  InvoiceController(this._ref) : super(InvoiceState());

  final Ref _ref;

  bool get _busy => state.busy;

  // ───────────────────────── Public API ─────────────────────────

  void reset() {
    if (_busy) return;
    state = InvoiceState();
  }

  void setError(String? message) {
    final msg = (message ?? '').trim();
    state = state.copyWith(error: msg.isEmpty ? null : msg);
  }

  /// ✅ Fetch invoice PDF bytes (for PdfPreviewScreen).
  /// Does NOT mutate state; UI handles a local "acting" flag.
  Future<Uint8List?> getInvoicePdfBytes(String invoiceId) async {
    if (_busy) return null;

    final id = invoiceId.trim();
    if (id.isEmpty) return null;

    state = state.copyWith(downloadingPdf: true, clearError: true);

    try {
      final svc = await _ref.read(zohoInvoicesServiceProvider.future);
      final bytes = await svc.getPdf(id);

      state = state.copyWith(downloadingPdf: false);
      return bytes;
    } catch (e) {
      state = state.copyWith(downloadingPdf: false, error: e.toString());
      SnackService.showError('Failed to load PDF');
      return null;
    }
  }

  /// Load invoice + payments. Safe to call multiple times; will refresh.
  Future<void> load(String invoiceId) async {
    final id = invoiceId.trim();
    if (id.isEmpty) return;
    if (_busy) return;

    state = state.copyWith(
      loading: true,
      loadingPayments: true,
      clearError: true,
      invoiceId: id,
      clearInvoice: true,
      clearPayments: true,
      clearEditingPaymentId: true,
      paymentDraft: PaymentDraft.today(),
    );

    try {
      final svc = await _ref.read(zohoInvoicesServiceProvider.future);

      final inv = await svc.get(id);

      // Payments endpoint is optional. If not implemented, keep empty list.
      List<ZohoInvoicePayment> pays = const <ZohoInvoicePayment>[];
      try {
        pays = await svc.listPayments(id);
      } catch (_) {
        pays = const <ZohoInvoicePayment>[];
      }

      state = state.copyWith(
        loading: false,
        loadingPayments: false,
        invoice: inv,
        payments: pays,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        loadingPayments: false,
        error: e.toString(),
      );
      SnackService.showError('Failed to load invoice');
    }
  }

  /// Refresh only payments (keeps invoice as-is).
  Future<void> refreshPayments() async {
    final id = (state.invoiceId ?? '').trim();
    if (id.isEmpty) return;
    if (_busy) return;

    state = state.copyWith(loadingPayments: true, clearError: true);

    try {
      final svc = await _ref.read(zohoInvoicesServiceProvider.future);
      final pays = await svc.listPayments(id);
      state = state.copyWith(loadingPayments: false, payments: pays);
    } catch (e) {
      state = state.copyWith(loadingPayments: false, error: e.toString());
      SnackService.showError('Failed to load payments');
    }
  }

  // ───────────────────────── Payment Draft ─────────────────────────

  void startNewPayment() {
    if (_busy) return;
    state = state.copyWith(
      clearEditingPaymentId: true,
      paymentDraft: PaymentDraft.today(),
      clearError: true,
    );
  }

  void startEditPayment(ZohoInvoicePayment p) {
    if (_busy) return;

    final id = p.paymentId.trim();
    if (id.isEmpty) return;

    final dt = (p.date ?? DateTime.now());
    final dateOnly = DateTime(dt.year, dt.month, dt.day);

    state = state.copyWith(
      editingPaymentId: id,
      paymentDraft: PaymentDraft(
        amount: p.amount,
        date: dateOnly,
        mode: p.mode,
        referenceNumber: p.referenceNumber,
        description: p.description,
        accountId: null, // response often doesn't include it
      ),
      clearError: true,
    );
  }

  void cancelPaymentEdit() {
    if (_busy) return;
    startNewPayment();
    SnackService.showSuccess('Payment edit cancelled');
  }

  /// ✅ IMPORTANT: does not overwrite fields with null unless you explicitly clear.
  void patchPaymentDraft({
    num? amount,
    DateTime? date,
    String? mode,
    bool clearMode = false,
    String? referenceNumber,
    bool clearReferenceNumber = false,
    String? description,
    bool clearDescription = false,
    String? accountId,
    bool clearAccountId = false,
  }) {
    if (_busy) return;

    final d = state.paymentDraft;

    DateTime? nextDate;
    if (date != null) {
      nextDate = DateTime(date.year, date.month, date.day);
    }

    state = state.copyWith(
      clearError: true,
      paymentDraft: d.copyWith(
        amount: amount ?? d.amount,
        date: nextDate ?? d.date,
        mode: clearMode ? null : (mode ?? d.mode),
        referenceNumber: clearReferenceNumber
            ? null
            : (referenceNumber ?? d.referenceNumber),
        description: clearDescription ? null : (description ?? d.description),
        accountId: clearAccountId ? null : (accountId ?? d.accountId),
      ),
    );
  }

  // ───────────────────────── Payment Actions ─────────────────────────

  Future<bool> savePayment() async {
    if (_busy) return false;

    final invoiceId = (state.invoiceId ?? '').trim();
    if (invoiceId.isEmpty) {
      SnackService.showError('Missing invoice id');
      return false;
    }

    final draft = state.paymentDraft.withDateOnly();
    if (!_validatePaymentDraft(draft)) return false;

    state = state.copyWith(savingPayment: true, clearError: true);

    try {
      final svc = await _ref.read(zohoInvoicesServiceProvider.future);

      final editingId = (state.editingPaymentId ?? '').trim();
      if (editingId.isNotEmpty) {
        await svc.updatePayment(editingId, draft);
        SnackService.showSuccess('Payment updated');
      } else {
        await svc.recordPayment(invoiceId, draft);
        SnackService.showSuccess('Payment recorded');
      }

      final pays = await svc.listPayments(invoiceId);

      state = state.copyWith(
        savingPayment: false,
        payments: pays,
        clearEditingPaymentId: true,
        paymentDraft: PaymentDraft.today(),
      );

      return true;
    } catch (e) {
      state = state.copyWith(savingPayment: false, error: e.toString());
      SnackService.showError('Failed to save payment');
      return false;
    }
  }

  Future<bool> deletePayment(String paymentId) async {
    if (_busy) return false;

    final id = paymentId.trim();
    if (id.isEmpty) return false;

    final invoiceId = (state.invoiceId ?? '').trim();
    if (invoiceId.isEmpty) return false;

    state = state.copyWith(deletingPayment: true, clearError: true);

    try {
      final svc = await _ref.read(zohoInvoicesServiceProvider.future);
      await svc.deletePayment(id);

      final pays = await svc.listPayments(invoiceId);

      final wasEditingThis = (state.editingPaymentId ?? '').trim() == id;

      state = state.copyWith(
        deletingPayment: false,
        payments: pays,
        editingPaymentId: wasEditingThis ? null : state.editingPaymentId,
        paymentDraft: wasEditingThis
            ? PaymentDraft.today()
            : state.paymentDraft,
      );

      SnackService.showSuccess('Payment deleted');
      return true;
    } catch (e) {
      state = state.copyWith(deletingPayment: false, error: e.toString());
      SnackService.showError('Failed to delete payment');
      return false;
    }
  }

  // ───────────────────────── Validation ─────────────────────────

  bool _validatePaymentDraft(PaymentDraft d) {
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
}
