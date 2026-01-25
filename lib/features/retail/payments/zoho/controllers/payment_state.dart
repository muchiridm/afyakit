// lib/features/retail/sales/payments/controllers/payment_state.dart

import 'package:flutter/foundation.dart';

import 'package:afyakit/features/retail/shared/models/zoho_payment_draft.dart';
import 'package:afyakit/features/retail/shared/models/zoho_invoice_payment.dart';
import 'package:afyakit/features/retail/shared/models/zoho_payment_dtos.dart';

@immutable
class PaymentState {
  PaymentState({
    this.invoiceId,
    this.loading = false,
    this.loadingPayments = false,
    this.savingPayment = false,
    this.deletingPayment = false,
    this.editingPaymentId,
    List<ZohoInvoicePayment>? payments,
    this.invoiceSummary,
    ZohoPaymentDraft? paymentDraft,
    this.error,
  }) : payments = payments ?? const <ZohoInvoicePayment>[],
       // ✅ draft MUST carry invoiceId so backend receives invoice_id
       paymentDraft =
           paymentDraft ??
           ZohoPaymentDraft.today(invoiceId: (invoiceId ?? '').trim());

  final String? invoiceId;

  final bool loading;
  final bool loadingPayments;
  final bool savingPayment;
  final bool deletingPayment;

  final String? editingPaymentId;

  final List<ZohoInvoicePayment> payments;

  /// From backend listPaymentsWithBalance
  final InvoiceBalanceSummary? invoiceSummary;

  final ZohoPaymentDraft paymentDraft;

  final String? error;

  bool get busy =>
      loading || loadingPayments || savingPayment || deletingPayment;

  PaymentState copyWith({
    String? invoiceId,
    bool? loading,
    bool? loadingPayments,
    bool? savingPayment,
    bool? deletingPayment,
    String? editingPaymentId,
    bool clearEditingPaymentId = false,
    List<ZohoInvoicePayment>? payments,
    bool clearPayments = false,
    InvoiceBalanceSummary? invoiceSummary,
    bool clearInvoiceSummary = false,
    ZohoPaymentDraft? paymentDraft,
    String? error,
    bool clearError = false,
  }) {
    return PaymentState(
      invoiceId: invoiceId ?? this.invoiceId,
      loading: loading ?? this.loading,
      loadingPayments: loadingPayments ?? this.loadingPayments,
      savingPayment: savingPayment ?? this.savingPayment,
      deletingPayment: deletingPayment ?? this.deletingPayment,
      editingPaymentId: clearEditingPaymentId
          ? null
          : (editingPaymentId ?? this.editingPaymentId),
      payments: clearPayments
          ? const <ZohoInvoicePayment>[]
          : (payments ?? this.payments),
      invoiceSummary: clearInvoiceSummary
          ? null
          : (invoiceSummary ?? this.invoiceSummary),
      paymentDraft: paymentDraft ?? this.paymentDraft,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
