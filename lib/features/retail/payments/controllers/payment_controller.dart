// lib/features/retail/payments/controllers/payment_controller.dart

import 'package:afyakit/features/retail/mpesa/models/mpesa_payment.dart';
import 'package:afyakit/features/retail/mpesa/models/mpesa_stk_draft.dart';
import 'package:afyakit/features/retail/mpesa/services/mpesa_service.dart';
import 'package:afyakit/features/retail/payments/models/zoho_invoice_payment.dart';
import 'package:afyakit/features/retail/payments/models/zoho_payment_draft.dart';
import 'package:afyakit/features/retail/payments/models/zoho_payment_dtos.dart';
import 'package:afyakit/features/retail/payments/services/zoho_payments_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/utils/normalize/normalize_phone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final paymentControllerProvider =
    StateNotifierProvider.family<PaymentController, PaymentState, String>(
      (Ref ref, String invoiceId) => PaymentController(ref, invoiceId),
    );

@immutable
class PaymentState {
  PaymentState({
    this.invoiceId,
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
    this.pendingAmount,
    this.suggestedMpesaPhone,
    this.defaultsSeeded = false,
  }) : payments = payments ?? const <ZohoInvoicePayment>[],
       paymentDraft =
           paymentDraft ??
           ZohoPaymentDraft.today(invoiceId: (invoiceId ?? '').trim());

  final String? invoiceId;

  final bool loadingPayments;
  final bool savingPayment;
  final bool deletingPayment;
  final bool payingMpesa;

  final String? editingPaymentId;

  final List<ZohoInvoicePayment> payments;
  final InvoiceBalanceSummary? invoiceSummary;
  final ZohoPaymentDraft paymentDraft;

  final String? error;
  final MpesaPayment? mpesaLastPayment;

  final num? pendingAmount;
  final String? suggestedMpesaPhone;
  final bool defaultsSeeded;

  bool get busy {
    return loadingPayments || savingPayment || deletingPayment || payingMpesa;
  }

  bool get isEditing {
    return (editingPaymentId ?? '').trim().isNotEmpty;
  }

  PaymentState copyWith({
    String? invoiceId,
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
    num? pendingAmount,
    bool clearPendingAmount = false,
    String? suggestedMpesaPhone,
    bool clearSuggestedMpesaPhone = false,
    bool? defaultsSeeded,
  }) {
    return PaymentState(
      invoiceId: invoiceId ?? this.invoiceId,
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

class PaymentController extends StateNotifier<PaymentState> {
  PaymentController(this._ref, String invoiceId)
    : super(
        PaymentState(
          invoiceId: invoiceId.trim(),
          paymentDraft: ZohoPaymentDraft.today(invoiceId: invoiceId.trim()),
        ),
      ) {
    final String id = this.invoiceId;

    if (id.isNotEmpty) {
      // ignore: discarded_futures
      load();
    }
  }

  final Ref _ref;

  PaymentState get publicState => state;

  String get invoiceId {
    return (state.invoiceId ?? '').trim();
  }

  bool get _busy => state.busy;

  Future<void> load() async {
    final String id = invoiceId;
    if (id.isEmpty || _busy) return;

    state = state.copyWith(
      loadingPayments: true,
      clearError: true,
      clearPayments: true,
      clearInvoiceSummary: true,
      clearEditingPaymentId: true,
      clearMpesaLastPayment: true,
      clearPendingAmount: true,
      clearSuggestedMpesaPhone: true,
      defaultsSeeded: false,
      paymentDraft: ZohoPaymentDraft.today(invoiceId: id),
    );

    await _reloadPayments(
      invoiceId: id,
      setLoadingFalse: true,
      resetDefaults: true,
      errorMessage: 'Failed to load payments',
    );
  }

  Future<void> refresh() async {
    final String id = invoiceId;
    if (id.isEmpty || _busy) return;

    state = state.copyWith(
      loadingPayments: true,
      clearError: true,
      clearPendingAmount: true,
      clearMpesaLastPayment: true,
      defaultsSeeded: false,
    );

    await _reloadPayments(
      invoiceId: id,
      setLoadingFalse: true,
      resetDefaults: true,
      errorMessage: 'Failed to load payments',
    );
  }

  Future<void> _reloadPayments({
    required String invoiceId,
    required bool setLoadingFalse,
    required bool resetDefaults,
    required String errorMessage,
  }) async {
    try {
      final ZohoPaymentsService svc = await _ref.read(
        zohoPaymentsServiceProvider.future,
      );

      final ListInvoicePaymentsResult payRes = await svc
          .listInvoicePaymentsWithBalance(invoiceId);

      state = state.copyWith(
        loadingPayments: setLoadingFalse ? false : state.loadingPayments,
        payments: payRes.payments,
        invoiceSummary: payRes.invoice,
        clearError: true,
        defaultsSeeded: resetDefaults ? false : state.defaultsSeeded,
      );

      // ignore: discarded_futures
      ensureSeededDefaults();
    } catch (error) {
      state = state.copyWith(
        loadingPayments: setLoadingFalse ? false : state.loadingPayments,
        error: _err(error),
      );

      SnackService.showError(errorMessage);
    }
  }

  void seedFromInvoiceContext({
    num? pendingAmount,
    String? suggestedPhone,
    bool force = false,
  }) {
    if (_busy) return;

    final num? nextPending = _normPending(pendingAmount);
    final String? nextPhone = _normPhone(suggestedPhone);

    final num? curPending = state.pendingAmount;
    final String? curPhone = _normPhone(state.suggestedMpesaPhone);

    final bool shouldSetPending =
        force || (nextPending != null && nextPending != curPending);

    final bool shouldSetPhone = force
        ? nextPhone != null && nextPhone != curPhone
        : curPhone == null && nextPhone != null;

    if (shouldSetPending || shouldSetPhone) {
      state = state.copyWith(
        pendingAmount: shouldSetPending ? nextPending : curPending,
        suggestedMpesaPhone: shouldSetPhone
            ? nextPhone
            : state.suggestedMpesaPhone,
      );
    }

    final num draftAmount = state.paymentDraft.amount;

    if (nextPending != null && nextPending > 0) {
      final bool shouldSeedAmount = force || draftAmount <= 0;

      if (shouldSeedAmount) {
        patchDraft(amount: nextPending);
      }
    }
  }

  void startNewPayment() {
    if (_busy) return;

    final String id = invoiceId;

    state = state.copyWith(
      clearEditingPaymentId: true,
      paymentDraft: ZohoPaymentDraft.today(invoiceId: id),
      clearError: true,
    );

    // ignore: discarded_futures
    ensureSeededDefaults();
  }

  void startEditPayment(ZohoInvoicePayment payment) {
    if (_busy) return;

    final String paymentId = payment.paymentId.trim();
    if (paymentId.isEmpty) return;

    final DateTime sourceDate = payment.date ?? DateTime.now();
    final DateTime dateOnly = DateTime(
      sourceDate.year,
      sourceDate.month,
      sourceDate.day,
    );

    state = state.copyWith(
      editingPaymentId: paymentId,
      paymentDraft: ZohoPaymentDraft(
        invoiceId: invoiceId,
        amount: payment.amount,
        date: dateOnly,
        mode: payment.mode,
        description: payment.description,
        reference: payment.reference,
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
    String? reference,
    bool clearReference = false,
  }) {
    if (_busy) return;

    final ZohoPaymentDraft draft = state.paymentDraft;

    final DateTime? nextDate = date == null
        ? null
        : DateTime(date.year, date.month, date.day);

    state = state.copyWith(
      clearError: true,
      paymentDraft: draft.copyWith(
        amount: amount ?? draft.amount,
        date: nextDate ?? draft.date,
        mode: mode,
        clearMode: clearMode,
        description: description,
        clearDescription: clearDescription,
        accountId: accountId,
        clearAccountId: clearAccountId,
        reference: reference,
        clearReference: clearReference,
      ),
    );
  }

  Future<bool> savePayment() async {
    if (_busy) return false;

    final String id = invoiceId;

    if (id.isEmpty) {
      SnackService.showError('Missing invoice id');
      return false;
    }

    final ZohoPaymentDraft draft = state.paymentDraft
        .copyWith(invoiceId: id)
        .withDateOnly();

    if (!_validateDraft(draft)) return false;

    state = state.copyWith(savingPayment: true, clearError: true);

    try {
      final ZohoPaymentsService svc = await _ref.read(
        zohoPaymentsServiceProvider.future,
      );

      final String editingId = (state.editingPaymentId ?? '').trim();

      if (editingId.isNotEmpty) {
        await svc.update(editingId, draft);
        SnackService.showSuccess('Payment updated');
      } else {
        await svc.create(draft);
        SnackService.showSuccess('Payment recorded');
      }

      final ListInvoicePaymentsResult payRes = await svc
          .listInvoicePaymentsWithBalance(id);

      state = state.copyWith(
        savingPayment: false,
        payments: payRes.payments,
        invoiceSummary: payRes.invoice,
        clearEditingPaymentId: true,
        paymentDraft: ZohoPaymentDraft.today(invoiceId: id),
        clearPendingAmount: true,
        defaultsSeeded: false,
      );

      // ignore: discarded_futures
      ensureSeededDefaults();

      return true;
    } catch (error) {
      state = state.copyWith(savingPayment: false, error: _err(error));

      SnackService.showError('Failed to save payment');
      return false;
    }
  }

  Future<bool> deletePayment(String paymentId) async {
    if (_busy) return false;

    final String pid = paymentId.trim();
    final String id = invoiceId;

    if (pid.isEmpty || id.isEmpty) return false;

    state = state.copyWith(deletingPayment: true, clearError: true);

    try {
      final ZohoPaymentsService svc = await _ref.read(
        zohoPaymentsServiceProvider.future,
      );

      await svc.remove(pid);

      final ListInvoicePaymentsResult payRes = await svc
          .listInvoicePaymentsWithBalance(id);

      final bool wasEditingThis = (state.editingPaymentId ?? '').trim() == pid;

      state = state.copyWith(
        deletingPayment: false,
        payments: payRes.payments,
        invoiceSummary: payRes.invoice,
        editingPaymentId: wasEditingThis ? null : state.editingPaymentId,
        paymentDraft: wasEditingThis
            ? ZohoPaymentDraft.today(invoiceId: id)
            : state.paymentDraft,
        clearPendingAmount: true,
        defaultsSeeded: false,
      );

      SnackService.showSuccess('Payment deleted');

      // ignore: discarded_futures
      ensureSeededDefaults();

      return true;
    } catch (error) {
      state = state.copyWith(deletingPayment: false, error: _err(error));

      SnackService.showError('Failed to delete payment');
      return false;
    }
  }

  Future<bool> payViaMpesaStk({
    required String phone,
    num? amount,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (_busy) return false;

    final String id = invoiceId;

    if (id.isEmpty) {
      SnackService.showError('Missing invoice id');
      return false;
    }

    final String? normalizedPhone = normalizeMpesaPhoneKE(phone);

    if (normalizedPhone == null) {
      SnackService.showError(
        'Invalid phone. Use 07XXXXXXXX, 011XYYYYYY or 2547/2541XXXXXXXX',
      );
      return false;
    }

    final ZohoPaymentDraft baseDraft = state.paymentDraft
        .copyWith(invoiceId: id)
        .withDateOnly();

    final num effectiveAmount = amount != null && amount.isFinite
        ? amount
        : baseDraft.amount;

    if (!_validateMpesaAmount(effectiveAmount)) return false;

    if (!_validateAgainstPendingBalance(effectiveAmount)) return false;

    final int amountInt = effectiveAmount.round();

    if (amountInt <= 0) {
      SnackService.showError('Amount must be at least 1');
      return false;
    }

    if (amount != null && amount.isFinite && amount > 0) {
      patchDraft(amount: amount);
    }

    state = state.copyWith(
      payingMpesa: true,
      clearError: true,
      clearMpesaLastPayment: true,
    );

    try {
      final MpesaService mpesaSvc = await _ref.read(
        mpesaServiceProvider.future,
      );

      final MpesaPayment payment = await mpesaSvc.initiateAndWait(
        draft: MpesaStkInitiateDraft(
          purpose: 'invoice',
          purposeRef: id,
          amount: amountInt,
          phone: normalizedPhone,
          clientRequestId: 'stk_${DateTime.now().millisecondsSinceEpoch}',
        ),
        timeout: timeout,
        onTick: (MpesaPayment tick) {
          state = state.copyWith(mpesaLastPayment: tick);
        },
      );

      state = state.copyWith(mpesaLastPayment: payment);

      if (payment.isFailed) {
        final String message = (payment.resultDesc ?? '').trim();
        SnackService.showError(
          message.isEmpty ? 'M-Pesa payment failed' : message,
        );

        state = state.copyWith(payingMpesa: false);
        return false;
      }

      if (!payment.isSuccess) {
        SnackService.showError(
          'Payment still pending. Tap refresh to check status.',
        );

        state = state.copyWith(payingMpesa: false);
        return false;
      }

      final String syncStatus = (payment.zohoSyncStatus ?? '')
          .trim()
          .toLowerCase();

      SnackService.showSuccess(
        syncStatus == 'success'
            ? 'Payment received'
            : 'Payment received. Syncing to Zoho…',
      );

      state = state.copyWith(
        payingMpesa: false,
        loadingPayments: true,
        clearPendingAmount: true,
        defaultsSeeded: false,
      );

      await _reloadPayments(
        invoiceId: id,
        setLoadingFalse: true,
        resetDefaults: true,
        errorMessage: 'Payment received, but failed to refresh payments',
      );

      return true;
    } catch (error) {
      state = state.copyWith(payingMpesa: false, error: _err(error));

      SnackService.showError('Failed to initiate M-Pesa STK');
      return false;
    }
  }

  Future<void> ensureSeededDefaults() async {
    if (state.busy) return;
    if (state.isEditing) return;
    if (state.defaultsSeeded) return;

    final InvoiceBalanceSummary? summary = state.invoiceSummary;
    final num? pending = _pendingFromSummary(summary);

    if (pending != null && pending > 0) {
      state = state.copyWith(pendingAmount: pending);

      if (state.paymentDraft.amount <= 0) {
        patchDraft(amount: pending);
      }
    }

    state = state.copyWith(defaultsSeeded: summary != null);
  }

  bool _validateDraft(ZohoPaymentDraft draft) {
    final String inv = draft.invoiceId.trim();

    if (inv.isEmpty) {
      SnackService.showError('Missing invoice id');
      return false;
    }

    final num amount = draft.amount;

    if (amount.isNaN || amount.isInfinite || amount <= 0) {
      SnackService.showError('Amount must be greater than 0');
      return false;
    }

    if (draft.date.year < 2000) {
      SnackService.showError('Invalid payment date');
      return false;
    }

    return true;
  }

  bool _validateMpesaAmount(num amount) {
    if (amount.isNaN || amount.isInfinite || amount <= 0) {
      SnackService.showError('Amount must be greater than 0');
      return false;
    }

    return true;
  }

  bool _validateAgainstPendingBalance(num amount) {
    final num? pending = state.pendingAmount;

    if (pending == null || !pending.isFinite || pending <= 0) {
      return true;
    }

    if (amount > pending) {
      SnackService.showError(
        'Amount cannot exceed the balance (${pending.toString()})',
      );

      return false;
    }

    if (amount.round() > pending.round()) {
      SnackService.showError(
        'Amount cannot exceed the balance (${pending.round()})',
      );

      return false;
    }

    return true;
  }

  static num? _pendingFromSummary(InvoiceBalanceSummary? summary) {
    if (summary == null) return null;

    final num? balance = summary.balance;

    if (balance == null) return null;
    if (!balance.isFinite) return null;

    return balance <= 0 ? null : balance;
  }

  static num? _normPending(num? value) {
    if (value == null) return null;
    if (!value.isFinite) return null;

    return value <= 0 ? null : value;
  }

  static String? _normPhone(String? value) {
    final String text = (value ?? '').trim();

    return text.isEmpty ? null : text;
  }

  static String _err(Object error) {
    final String text = error.toString().trim();

    return text.isEmpty ? 'Unknown error' : text;
  }
}
