// lib/features/retail/sales/invoices/controllers/invoice_controller.dart

import 'dart:typed_data';

import 'package:afyakit/features/retail/invoices/models/zoho_invoice.dart';
import 'package:afyakit/features/retail/invoices/services/zoho_invoices_service.dart';
import 'package:afyakit/features/retail/payments/models/zoho_invoice_payment.dart';
import 'package:afyakit/features/retail/payments/models/zoho_payment_draft.dart';
import 'package:afyakit/features/retail/shared/models/zoho_email_draft.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final invoiceControllerProvider =
    StateNotifierProvider<InvoiceController, InvoiceState>(
      (Ref ref) => InvoiceController(ref),
    );

@immutable
class InvoiceState {
  InvoiceState({
    required this.invoiceId,
    this.loading = false,
    this.loadingPayments = false,
    this.downloadingPdf = false,
    this.savingPayment = false,
    this.deletingPayment = false,
    this.sending = false,
    this.error,
    this.invoice,
    this.payments = const <ZohoInvoicePayment>[],
    ZohoPaymentDraft? paymentDraft,
    this.editingPaymentId,
  }) : paymentDraft =
           paymentDraft ?? ZohoPaymentDraft.today(invoiceId: invoiceId.trim());

  final String invoiceId;

  final bool loading;
  final bool loadingPayments;
  final bool downloadingPdf;
  final bool savingPayment;
  final bool deletingPayment;
  final bool sending;

  final String? error;
  final ZohoInvoice? invoice;
  final List<ZohoInvoicePayment> payments;
  final ZohoPaymentDraft paymentDraft;
  final String? editingPaymentId;

  bool get busy {
    return loading ||
        loadingPayments ||
        downloadingPdf ||
        savingPayment ||
        deletingPayment ||
        sending;
  }

  bool get hasInvoice => invoice != null;
  bool get hasPayments => payments.isNotEmpty;

  String get customerName => (invoice?.customerName ?? '').trim();
  String get status => (invoice?.status ?? '').trim();

  num get total => invoice?.total ?? 0;
  num get balance => invoice?.balance ?? 0;

  bool get isEditingPayment => (editingPaymentId ?? '').trim().isNotEmpty;

  bool get canSendInvoice {
    return invoiceId.trim().isNotEmpty && !busy;
  }

  bool get canLoadPdf {
    return invoiceId.trim().isNotEmpty && !busy;
  }

  InvoiceState copyWith({
    String? invoiceId,
    bool resetDraftForInvoice = false,
    bool? loading,
    bool? loadingPayments,
    bool? downloadingPdf,
    bool? savingPayment,
    bool? deletingPayment,
    bool? sending,
    String? error,
    bool clearError = false,
    ZohoInvoice? invoice,
    bool clearInvoice = false,
    List<ZohoInvoicePayment>? payments,
    bool clearPayments = false,
    ZohoPaymentDraft? paymentDraft,
    String? editingPaymentId,
    bool clearEditingPaymentId = false,
  }) {
    final String nextInvoiceId = (invoiceId ?? this.invoiceId).trim();

    final ZohoPaymentDraft nextDraft = resetDraftForInvoice
        ? ZohoPaymentDraft.today(invoiceId: nextInvoiceId)
        : (paymentDraft ?? this.paymentDraft);

    return InvoiceState(
      invoiceId: nextInvoiceId,
      loading: loading ?? this.loading,
      loadingPayments: loadingPayments ?? this.loadingPayments,
      downloadingPdf: downloadingPdf ?? this.downloadingPdf,
      savingPayment: savingPayment ?? this.savingPayment,
      deletingPayment: deletingPayment ?? this.deletingPayment,
      sending: sending ?? this.sending,
      error: clearError ? null : (error ?? this.error),
      invoice: clearInvoice ? null : (invoice ?? this.invoice),
      payments: clearPayments
          ? const <ZohoInvoicePayment>[]
          : (payments ?? this.payments),
      paymentDraft: nextDraft,
      editingPaymentId: clearEditingPaymentId
          ? null
          : (editingPaymentId ?? this.editingPaymentId),
    );
  }
}

class InvoiceController extends StateNotifier<InvoiceState> {
  InvoiceController(this._ref) : super(InvoiceState(invoiceId: ''));

  final Ref _ref;

  InvoiceState get publicState => state;

  bool get _busy => state.busy;

  // ───────────────────────── Basics ─────────────────────────

  void reset() {
    if (_busy) return;

    final String id = state.invoiceId.trim();
    state = InvoiceState(invoiceId: id);
  }

  void setError(String? message) {
    final String msg = (message ?? '').trim();

    state = state.copyWith(
      error: msg.isEmpty ? null : msg,
      clearError: msg.isEmpty,
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void _syncInvoiceId(String invoiceId, {bool resetDraft = false}) {
    final String id = invoiceId.trim();
    if (id.isEmpty) return;

    if (state.invoiceId.trim() == id && !resetDraft) return;

    state = state.copyWith(invoiceId: id, resetDraftForInvoice: resetDraft);
  }

  // ───────────────────────── Load ─────────────────────────

  Future<void> load(String invoiceId) async {
    final String id = invoiceId.trim();

    if (id.isEmpty) return;
    if (_busy) return;

    state = state.copyWith(
      invoiceId: id,
      resetDraftForInvoice: true,
      loading: true,
      clearError: true,
      clearInvoice: true,
      clearPayments: true,
      clearEditingPaymentId: true,
    );

    try {
      final ZohoInvoicesService svc = await _ref.read(
        zohoInvoicesServiceProvider.future,
      );

      final ZohoInvoice invoice = await svc.get(id);

      if (!mounted) return;

      state = state.copyWith(loading: false, invoice: invoice);
    } catch (e) {
      if (!mounted) return;

      state = state.copyWith(loading: false, error: _err(e));

      SnackService.showError('Failed to load invoice');
    }
  }

  Future<void> refresh() async {
    final String id = state.invoiceId.trim();
    if (id.isEmpty) return;

    await load(id);
  }

  // ───────────────────────── PDF ─────────────────────────

  Future<Uint8List?> getInvoicePdfBytes(String invoiceId) async {
    final String id = invoiceId.trim();

    if (id.isEmpty) return null;
    if (_busy) return null;

    _syncInvoiceId(id);

    state = state.copyWith(downloadingPdf: true, clearError: true);

    try {
      final ZohoInvoicesService svc = await _ref.read(
        zohoInvoicesServiceProvider.future,
      );

      final Uint8List bytes = await svc.getPdf(id);

      if (!mounted) return null;

      state = state.copyWith(downloadingPdf: false);
      return bytes;
    } catch (e) {
      if (!mounted) return null;

      state = state.copyWith(downloadingPdf: false, error: _err(e));

      SnackService.showError('Failed to load PDF');
      return null;
    }
  }

  // ───────────────────────── Invoice actions ─────────────────────────

  Future<bool> sendInvoice(String invoiceId, {ZohoEmailDraft? email}) async {
    final String id = invoiceId.trim();

    if (id.isEmpty) return false;
    if (_busy) return false;

    _syncInvoiceId(id);

    final ZohoEmailDraft? draft = _buildEmailDraft(email);

    if (draft == null) return false;

    state = state.copyWith(sending: true, clearError: true);

    try {
      final ZohoInvoicesService svc = await _ref.read(
        zohoInvoicesServiceProvider.future,
      );

      await svc.sendInvoice(id, email: draft);

      if (!mounted) return false;

      state = state.copyWith(sending: false);
      SnackService.showSuccess('Invoice sent');

      return true;
    } catch (e) {
      if (!mounted) return false;

      state = state.copyWith(sending: false, error: _err(e));

      SnackService.showError('Failed to send invoice');
      return false;
    }
  }

  Future<bool> markInvoiceSent(String invoiceId) async {
    final String id = invoiceId.trim();

    if (id.isEmpty) return false;
    if (_busy) return false;

    _syncInvoiceId(id);

    state = state.copyWith(sending: true, clearError: true);

    try {
      final ZohoInvoicesService svc = await _ref.read(
        zohoInvoicesServiceProvider.future,
      );

      await svc.markSent(id);

      if (!mounted) return false;

      state = state.copyWith(sending: false);
      SnackService.showSuccess('Marked as sent');

      return true;
    } catch (e) {
      if (!mounted) return false;

      state = state.copyWith(sending: false, error: _err(e));

      SnackService.showError('Failed to mark invoice as sent');
      return false;
    }
  }

  Future<bool> sendAndMarkInvoiceSent(
    String invoiceId, {
    ZohoEmailDraft? email,
  }) async {
    final bool sent = await sendInvoice(invoiceId, email: email);
    if (!sent) return false;

    return markInvoiceSent(invoiceId);
  }

  ZohoEmailDraft? _buildEmailDraft(ZohoEmailDraft? email) {
    if (email != null) {
      if (!email.hasAnyRecipient) {
        const String msg =
            'Email requires recipients: add To or Contact Persons';

        state = state.copyWith(error: msg);
        SnackService.showError(msg);

        return null;
      }

      return email;
    }

    final ZohoInvoice? invoice = state.invoice;

    if (invoice == null) {
      const String msg = 'Invoice not loaded';

      state = state.copyWith(error: msg);
      SnackService.showError(msg);

      return null;
    }

    return ZohoEmailDraft(
      subject: 'Invoice ${invoice.invoiceNumber ?? invoice.invoiceId}',
      body: 'Please find your invoice attached.',
    );
  }

  static String _err(Object error) {
    final String raw = error.toString().trim();

    if (raw.isEmpty) return 'Unknown error';

    return raw
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^StateError:\s*'), '')
        .replaceFirst(RegExp(r'^Bad state:\s*'), '')
        .trim();
  }
}
