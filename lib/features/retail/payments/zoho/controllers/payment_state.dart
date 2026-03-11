// lib/features/retail/payments/zoho/controllers/payment_state.dart

import 'package:flutter/foundation.dart';

import 'package:afyakit/features/retail/payments/mpesa/models/mpesa_payment.dart';
import 'package:afyakit/features/retail/shared/models/zoho_invoice_payment.dart';
import 'package:afyakit/features/retail/shared/models/zoho_payment_draft.dart';
import 'package:afyakit/features/retail/shared/models/zoho_payment_dtos.dart';

@immutable
class PaymentState {
  PaymentState({
    this.invoiceId,
    this.loading = false,
    this.loadingPayments = false,
    this.savingPayment = false,
    this.deletingPayment = false,
    this.payingMpesa = false,
    this.editingPaymentId,
    List<ZohoInvoicePayment>? payments,
    this.invoiceSummary,
    ZohoPaymentDraft? paymentDraft,
    this.error,
    this.mpesaLastPayment,

    // ✅ defaults / hints
    this.pendingAmount,
    this.suggestedMpesaPhone,
    this.defaultsSeeded = false,
  }) : payments = payments ?? const <ZohoInvoicePayment>[],
       paymentDraft =
           paymentDraft ??
           ZohoPaymentDraft.today(invoiceId: (invoiceId ?? '').trim());

  final String? invoiceId;

  final bool loading;
  final bool loadingPayments;
  final bool savingPayment;
  final bool deletingPayment;

  /// ✅ Used to disable UI while STK is in progress
  final bool payingMpesa;

  final String? editingPaymentId;

  final List<ZohoInvoicePayment> payments;

  /// From backend listPaymentsWithBalance (or equivalent)
  final InvoiceBalanceSummary? invoiceSummary;

  final ZohoPaymentDraft paymentDraft;

  final String? error;

  /// Optional: last seen mpesa status (useful for UI)
  final MpesaPayment? mpesaLastPayment;

  /// ✅ pending amount (balance due / outstanding)
  final num? pendingAmount;

  /// ✅ phone to prefill prompt (registered phone)
  final String? suggestedMpesaPhone;

  /// ✅ internal guard so we only seed once per open (and don’t fight user edits)
  final bool defaultsSeeded;

  bool get busy =>
      loading ||
      loadingPayments ||
      savingPayment ||
      deletingPayment ||
      payingMpesa;

  bool get isEditing => (editingPaymentId ?? '').trim().isNotEmpty;

  PaymentState copyWith({
    String? invoiceId,
    bool? loading,
    bool? loadingPayments,
    bool? savingPayment,
    bool? deletingPayment,
    bool? payingMpesa,
    String? editingPaymentId,
    bool clearEditingPaymentId = false,
    List<ZohoInvoicePayment>? payments,
    bool clearPayments = false,
    InvoiceBalanceSummary? invoiceSummary,
    bool clearInvoiceSummary = false,
    ZohoPaymentDraft? paymentDraft,
    String? error,
    bool clearError = false,
    MpesaPayment? mpesaLastPayment,
    bool clearMpesaLastPayment = false,

    // ✅ defaults / hints
    num? pendingAmount,
    bool clearPendingAmount = false,
    String? suggestedMpesaPhone,
    bool clearSuggestedMpesaPhone = false,
    bool? defaultsSeeded,
  }) {
    return PaymentState(
      invoiceId: invoiceId ?? this.invoiceId,
      loading: loading ?? this.loading,
      loadingPayments: loadingPayments ?? this.loadingPayments,
      savingPayment: savingPayment ?? this.savingPayment,
      deletingPayment: deletingPayment ?? this.deletingPayment,
      payingMpesa: payingMpesa ?? this.payingMpesa,
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
      mpesaLastPayment: clearMpesaLastPayment
          ? null
          : (mpesaLastPayment ?? this.mpesaLastPayment),
      pendingAmount: clearPendingAmount
          ? null
          : (pendingAmount ?? this.pendingAmount),
      suggestedMpesaPhone: clearSuggestedMpesaPhone
          ? null
          : (suggestedMpesaPhone ?? this.suggestedMpesaPhone),
      defaultsSeeded: defaultsSeeded ?? this.defaultsSeeded,
    );
  }
}
