// lib/features/retail/sales/invoices/controllers/invoice_controller.dart

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/shared/models/zoho_email_draft.dart';
import 'package:afyakit/features/retail/invoices/controllers/invoice_state.dart';
import 'package:afyakit/features/retail/invoices/zoho_invoice.dart';
import 'package:afyakit/features/retail/invoices/zoho_invoices_service.dart';

import 'package:afyakit/shared/services/snack_service.dart';

final invoiceControllerProvider =
    StateNotifierProvider<InvoiceController, InvoiceState>(
      (ref) => InvoiceController(ref),
    );

class InvoiceController extends StateNotifier<InvoiceState> {
  InvoiceController(this._ref) : super(InvoiceState(invoiceId: ''));

  final Ref _ref;

  InvoiceState get publicState => state;

  bool get _busy => state.busy;

  // ───────────────────────── Basics ─────────────────────────

  void reset() {
    if (_busy) return;

    // Keep the current invoiceId (state requires it), clear the rest.
    final id = state.invoiceId.trim();
    state = InvoiceState(
      invoiceId: id,
      // paymentDraft will be rebuilt by InvoiceState using PaymentDraft.today(invoiceId: id)
    );
  }

  void setError(String? message) {
    final msg = (message ?? '').trim();
    state = state.copyWith(error: msg.isEmpty ? null : msg);
  }

  // ───────────────────────── PDF ─────────────────────────

  Future<Uint8List?> getInvoicePdfBytes(String invoiceId) async {
    if (_busy) return null;

    final id = invoiceId.trim();
    if (id.isEmpty) return null;

    // Ensure state invoiceId matches the request (helps UI consistency)
    if (state.invoiceId.trim() != id) {
      state = state.copyWith(
        invoiceId: id,
        resetDraftForInvoice: false, // pdf doesn't need to reset draft
      );
    }

    state = state.copyWith(downloadingPdf: true, clearError: true);

    try {
      final svc = await _ref.read(zohoInvoicesServiceProvider.future);
      final bytes = await svc.getPdf(id);

      state = state.copyWith(downloadingPdf: false);
      return bytes;
    } catch (e) {
      state = state.copyWith(downloadingPdf: false, error: _err(e));
      SnackService.showError('Failed to load PDF');
      return null;
    }
  }

  // ───────────────────────── Invoice actions ─────────────────────────

  Future<bool> sendInvoice(String invoiceId, {ZohoEmailDraft? email}) async {
    if (_busy) return false;

    final id = invoiceId.trim();
    if (id.isEmpty) return false;

    // Keep state consistent with requested invoice
    if (state.invoiceId.trim() != id) {
      state = state.copyWith(invoiceId: id, resetDraftForInvoice: false);
    }

    final inv = state.invoice;

    ZohoEmailDraft draft;
    if (email == null) {
      if (inv == null) {
        const msg = 'Invoice not loaded';
        state = state.copyWith(error: msg);
        SnackService.showError(msg);
        return false;
      }

      draft = ZohoEmailDraft(
        subject: 'Invoice ${inv.invoiceNumber ?? inv.invoiceId}',
        body: 'Please find your invoice attached.',
      );
    } else {
      draft = email;

      if (!draft.hasAnyRecipient) {
        const msg = 'Email requires recipients: add To or Contact Persons';
        state = state.copyWith(error: msg);
        SnackService.showError(msg);
        return false;
      }
    }

    state = state.copyWith(sending: true, clearError: true);

    try {
      final svc = await _ref.read(zohoInvoicesServiceProvider.future);
      await svc.sendInvoice(id, email: draft);

      state = state.copyWith(sending: false);
      SnackService.showSuccess('Invoice sent');
      return true;
    } catch (e) {
      state = state.copyWith(sending: false, error: _err(e));
      SnackService.showError('Failed to send invoice');
      return false;
    }
  }

  Future<bool> markInvoiceSent(String invoiceId) async {
    if (_busy) return false;

    final id = invoiceId.trim();
    if (id.isEmpty) return false;

    if (state.invoiceId.trim() != id) {
      state = state.copyWith(invoiceId: id, resetDraftForInvoice: false);
    }

    state = state.copyWith(sending: true, clearError: true);

    try {
      final svc = await _ref.read(zohoInvoicesServiceProvider.future);
      await svc.markSent(id);

      state = state.copyWith(sending: false);
      SnackService.showSuccess('Marked as sent');
      return true;
    } catch (e) {
      state = state.copyWith(sending: false, error: _err(e));
      SnackService.showError('Failed to mark invoice as sent');
      return false;
    }
  }

  // ───────────────────────── Load ─────────────────────────

  Future<void> load(String invoiceId) async {
    final id = invoiceId.trim();
    if (id.isEmpty) return;
    if (_busy) return;

    state = state.copyWith(
      loading: true,
      clearError: true,
      invoiceId: id,
      resetDraftForInvoice: true, // ✅ important: draft must match invoice
      clearInvoice: true,
      clearPayments: true,
      clearEditingPaymentId: true,
    );

    try {
      final svc = await _ref.read(zohoInvoicesServiceProvider.future);
      final ZohoInvoice inv = await svc.get(id);

      state = state.copyWith(loading: false, invoice: inv);
    } catch (e) {
      state = state.copyWith(loading: false, error: _err(e));
      SnackService.showError('Failed to load invoice');
    }
  }

  static String _err(Object e) {
    final s = e.toString().trim();
    return s.isEmpty ? 'Unknown error' : s;
  }
}
