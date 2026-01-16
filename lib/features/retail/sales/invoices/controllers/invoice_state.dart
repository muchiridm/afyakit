import 'package:flutter/foundation.dart';

import 'package:afyakit/features/retail/sales/invoices/models/zoho_invoice.dart';
import 'package:afyakit/features/retail/sales/invoices/models/zoho_invoice_payment.dart';
import 'package:afyakit/features/retail/sales/invoices/models/payment_draft.dart';

@immutable
class InvoiceState {
  InvoiceState({
    this.loading = false,
    this.loadingPayments = false,
    this.downloadingPdf = false, // ✅ MUST default to false
    this.savingPayment = false,
    this.deletingPayment = false,
    this.error,
    this.invoiceId,
    this.invoice,
    this.payments = const <ZohoInvoicePayment>[],
    PaymentDraft? paymentDraft,
    this.editingPaymentId,
  }) : paymentDraft = paymentDraft ?? PaymentDraft.today();

  final bool loading;
  final bool loadingPayments;

  final bool downloadingPdf; // ✅ MUST be non-nullable bool

  final bool savingPayment;
  final bool deletingPayment;

  final String? error;

  final String? invoiceId;
  final ZohoInvoice? invoice;

  final List<ZohoInvoicePayment> payments;

  final PaymentDraft paymentDraft;

  final String? editingPaymentId;

  bool get busy =>
      loading ||
      loadingPayments ||
      downloadingPdf ||
      savingPayment ||
      deletingPayment;

  bool get hasInvoice => invoice != null;
  bool get hasPayments => payments.isNotEmpty;

  String get customerName => (invoice?.customerName ?? '').trim();
  String get status => (invoice?.status ?? '').trim();
  num get total => invoice?.total ?? 0;
  num get balance => invoice?.balance ?? 0;

  bool get isEditingPayment => (editingPaymentId ?? '').trim().isNotEmpty;

  InvoiceState copyWith({
    bool? loading,
    bool? loadingPayments,
    bool? downloadingPdf, // ✅ optional param
    bool? savingPayment,
    bool? deletingPayment,
    String? error,
    bool clearError = false,
    String? invoiceId,
    bool clearInvoiceId = false,
    ZohoInvoice? invoice,
    bool clearInvoice = false,
    List<ZohoInvoicePayment>? payments,
    bool clearPayments = false,
    PaymentDraft? paymentDraft,
    String? editingPaymentId,
    bool clearEditingPaymentId = false,
  }) {
    return InvoiceState(
      loading: loading ?? this.loading,
      loadingPayments: loadingPayments ?? this.loadingPayments,
      downloadingPdf: downloadingPdf ?? this.downloadingPdf, // ✅ never null
      savingPayment: savingPayment ?? this.savingPayment,
      deletingPayment: deletingPayment ?? this.deletingPayment,
      error: clearError ? null : (error ?? this.error),
      invoiceId: clearInvoiceId ? null : (invoiceId ?? this.invoiceId),
      invoice: clearInvoice ? null : (invoice ?? this.invoice),
      payments: clearPayments
          ? const <ZohoInvoicePayment>[]
          : (payments ?? this.payments),
      paymentDraft: paymentDraft ?? this.paymentDraft,
      editingPaymentId: clearEditingPaymentId
          ? null
          : (editingPaymentId ?? this.editingPaymentId),
    );
  }
}
