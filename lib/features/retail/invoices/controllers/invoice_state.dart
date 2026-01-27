// lib/features/retail/sales/invoices/controllers/invoice_state.dart

import 'package:flutter/foundation.dart';

import 'package:afyakit/features/retail/shared/models/zoho_invoice.dart';
import 'package:afyakit/features/retail/shared/models/zoho_invoice_payment.dart';
import 'package:afyakit/features/retail/shared/models/zoho_payment_draft.dart';

@immutable
class InvoiceState {
  InvoiceState({
    required this.invoiceId, // ✅ required (non-nullable)
    this.loading = false,
    this.loadingPayments = false,
    this.downloadingPdf = false, // ✅ MUST default to false
    this.savingPayment = false,
    this.deletingPayment = false,

    // ✅ invoice actions busy flag (send / mark sent)
    this.sending = false,

    this.error,
    this.invoice,
    this.payments = const <ZohoInvoicePayment>[],
    ZohoPaymentDraft? paymentDraft,
    this.editingPaymentId,
  }) : paymentDraft =
           paymentDraft ?? ZohoPaymentDraft.today(invoiceId: invoiceId.trim());

  final bool loading;
  final bool loadingPayments;

  final bool downloadingPdf; // ✅ non-nullable bool

  final bool savingPayment;
  final bool deletingPayment;

  final bool sending;

  final String? error;

  /// ✅ Always known for this screen/controller instance.
  final String invoiceId;

  final ZohoInvoice? invoice;

  final List<ZohoInvoicePayment> payments;

  /// ✅ Draft must always contain invoice_id for backend create/update.
  final ZohoPaymentDraft paymentDraft;

  final String? editingPaymentId;

  bool get busy =>
      loading ||
      loadingPayments ||
      downloadingPdf ||
      savingPayment ||
      deletingPayment ||
      sending;

  bool get hasInvoice => invoice != null;
  bool get hasPayments => payments.isNotEmpty;

  String get customerName => (invoice?.customerName ?? '').trim();
  String get status => (invoice?.status ?? '').trim();
  num get total => invoice?.total ?? 0;
  num get balance => invoice?.balance ?? 0;

  bool get isEditingPayment => (editingPaymentId ?? '').trim().isNotEmpty;

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
    final nextInvoiceId = (invoiceId ?? this.invoiceId).trim();

    // If caller changes invoiceId and wants a clean draft tied to it.
    final nextDraft = resetDraftForInvoice
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
