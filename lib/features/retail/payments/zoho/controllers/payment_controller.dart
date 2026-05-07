// lib/features/retail/payments/zoho/controllers/payment_controller.dart

import 'package:afyakit/shared/utils/normalize/normalize_phone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/payments/zoho/controllers/payment_state.dart';
import 'package:afyakit/features/retail/shared/models/zoho_invoice_payment.dart';
import 'package:afyakit/features/retail/shared/models/zoho_payment_draft.dart';
import 'package:afyakit/features/retail/payments/zoho/services/zoho_payments_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';

import 'package:afyakit/features/retail/payments/mpesa/models/mpesa_stk_draft.dart';
import 'package:afyakit/features/retail/payments/mpesa/services/mpesa_service.dart';

import 'package:afyakit/features/retail/shared/models/zoho_payment_dtos.dart';

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
      // ignore: discarded_futures
      load();
    }
  }

  final Ref _ref;

  PaymentState get publicState => state;

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
      clearMpesaLastPayment: true,

      // ✅ allow fresh reseeding from parent context after load
      clearPendingAmount: true,
      clearSuggestedMpesaPhone: true,
      defaultsSeeded: false,

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

      // NOTE:
      // - Do NOT fetch contact here.
      // - Seeding phone should come from the invoice page (parent context).
      // - Amount seeding can be done from invoiceSummary via ensureSeededDefaults().
      //
      // ignore: discarded_futures
      ensureSeededDefaults();
    } catch (e) {
      state = state.copyWith(loadingPayments: false, error: _err(e));
      SnackService.showError('Failed to load payments');
    }
  }

  Future<void> refresh() async {
    final id = invoiceId;
    if (id.isEmpty || _busy) return;

    state = state.copyWith(
      loadingPayments: true,
      clearError: true,

      // ✅ after refresh, allow fresh reseeding from latest invoice balance
      clearPendingAmount: true,
      defaultsSeeded: false,

      // ✅ avoid stale M-Pesa success/failure banner/state lingering
      clearMpesaLastPayment: true,
    );

    try {
      final svc = await _ref.read(zohoPaymentsServiceProvider.future);
      final payRes = await svc.listInvoicePaymentsWithBalance(id);

      state = state.copyWith(
        loadingPayments: false,
        payments: payRes.payments,
        invoiceSummary: payRes.invoice,
      );

      // ✅ re-seed amount defaults from latest balance if needed
      // ignore: discarded_futures
      ensureSeededDefaults();
    } catch (e) {
      state = state.copyWith(loadingPayments: false, error: _err(e));
      SnackService.showError('Failed to load payments');
    }
  }

  // ───────────────────────── Parent-context seeding (NO network) ─────────────────────────

  /// ✅ Call this from Invoice screen/footer BEFORE opening PaymentEditorSheet.
  ///
  /// Rules:
  /// - never fights user: won’t overwrite amount if they already typed / draft has amount
  /// - won’t overwrite an existing suggested phone
  /// - safe to call repeatedly
  void seedFromInvoiceContext({
    num? pendingAmount,
    String? suggestedPhone,
    bool force = false,
  }) {
    if (_busy) return;

    final nextPending = _normPending(pendingAmount);
    final nextPhone = _normPhone(suggestedPhone);

    final curPending = state.pendingAmount;
    final curPhone = _normPhone(state.suggestedMpesaPhone);

    // pending: update state if changed (or force)
    final shouldSetPending =
        force || (nextPending != null && nextPending != curPending);

    // phone: only set if we don't already have one (or force)
    final shouldSetPhone = force
        ? (nextPhone != null && nextPhone != curPhone)
        : (curPhone == null && nextPhone != null);

    if (shouldSetPending || shouldSetPhone) {
      state = state.copyWith(
        pendingAmount: shouldSetPending ? nextPending : curPending,
        suggestedMpesaPhone: shouldSetPhone
            ? nextPhone
            : state.suggestedMpesaPhone,
      );
    }

    // If this is a fresh draft (amount <= 0), seed amount from pending
    // (unless force is false and user has already set amount)
    final draftAmt = state.paymentDraft.amount;
    if (nextPending != null && nextPending > 0) {
      final shouldSeedAmt = force ? true : (draftAmt <= 0);
      if (shouldSeedAmt) {
        patchDraft(amount: nextPending);
      }
    }
  }

  static num? _normPending(num? v) {
    if (v == null) return null;
    if (!v.isFinite) return null;
    if (v <= 0) return null;
    return v;
  }

  static String? _normPhone(String? v) {
    final s = (v ?? '').trim();
    return s.isEmpty ? null : s;
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

    // Note: do not auto-fetch anything here. Parent should call seedFromInvoiceContext().
    // ignore: discarded_futures
    ensureSeededDefaults();
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
        accountId: null,
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
        amount: amount ?? d.amount,
        date: nextDate ?? d.date,
        mode: clearMode ? null : (mode ?? d.mode),
        description: clearDescription ? null : (description ?? d.description),
        accountId: clearAccountId ? null : (accountId ?? d.accountId),
      ),
    );
  }

  // ───────────────────────── Actions (Zoho manual) ─────────────────────────

  Future<bool> savePayment() async {
    if (_busy) return false;

    final invId = invoiceId;
    if (invId.isEmpty) {
      SnackService.showError('Missing invoice id');
      return false;
    }

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

      final payRes = await svc.listInvoicePaymentsWithBalance(invId);

      state = state.copyWith(
        savingPayment: false,
        payments: payRes.payments,
        invoiceSummary: payRes.invoice,
        clearEditingPaymentId: true,
        paymentDraft: ZohoPaymentDraft.today(invoiceId: invId),

        // ✅ reseed after save
        clearPendingAmount: true,
        defaultsSeeded: false,
      );

      // ignore: discarded_futures
      ensureSeededDefaults();

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

      // ignore: discarded_futures
      ensureSeededDefaults();

      return true;
    } catch (e) {
      state = state.copyWith(deletingPayment: false, error: _err(e));
      SnackService.showError('Failed to delete payment');
      return false;
    }
  }

  // ───────────────────────── Actions (M-Pesa STK) ─────────────────────────

  // ───────────────────────── Actions (M-Pesa STK) ─────────────────────────

  Future<bool> payViaMpesaStk({
    required String phone,

    /// ✅ Optional override to support partial payments.
    /// If null => uses current draft amount.
    num? amount,

    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (_busy) return false;

    final invId = invoiceId;
    if (invId.isEmpty) {
      SnackService.showError('Missing invoice id');
      return false;
    }

    // ✅ Normalize phone to M-Pesa MSISDN: 2547XXXXXXXX or 2541XXXXXXXX (no +, no 0-prefix)
    final normalized = normalizeMpesaPhoneKE(phone);
    if (normalized == null) {
      SnackService.showError(
        'Invalid phone. Use 07XXXXXXXX, 011XYYYYYY or 2547/2541XXXXXXXX',
      );
      return false;
    }

    // Draft base (date only)
    final baseDraft = state.paymentDraft
        .copyWith(invoiceId: invId)
        .withDateOnly();

    // ✅ If caller provided amount, treat it as the effective amount (partial payments).
    final effectiveAmount = (amount != null && amount.isFinite)
        ? amount
        : baseDraft.amount;

    // Keep UI draft in sync (does not fight user; this is an explicit pay action)
    if (amount != null && amount.isFinite && amount > 0) {
      patchDraft(amount: amount);
    }

    // Validate amount
    if (effectiveAmount.isNaN ||
        effectiveAmount.isInfinite ||
        effectiveAmount <= 0) {
      SnackService.showError('Amount must be greater than 0');
      return false;
    }

    // ✅ Enforce partial-payment constraint: cannot exceed pending balance if known
    final pending =
        state.pendingAmount; // seeded from invoice screen OR invoice summary
    if (pending != null &&
        pending.isFinite &&
        pending > 0 &&
        effectiveAmount > pending) {
      SnackService.showError(
        'Amount cannot exceed the balance (${pending.toString()})',
      );
      return false;
    }

    // M-Pesa is integer KES. Round sensibly.
    final amtInt = effectiveAmount.round();
    if (amtInt <= 0) {
      SnackService.showError('Amount must be at least 1');
      return false;
    }

    // If pending exists, also enforce integer vs pending upper bound (rounded)
    if (pending != null && pending.isFinite && pending > 0) {
      final pendingInt = pending.round();
      if (amtInt > pendingInt) {
        SnackService.showError(
          'Amount cannot exceed the balance ($pendingInt)',
        );
        return false;
      }
    }

    state = state.copyWith(
      payingMpesa: true,
      clearError: true,
      clearMpesaLastPayment: true,
    );

    try {
      final mpesaSvc = await _ref.read(mpesaServiceProvider.future);

      final p = await mpesaSvc.initiateAndWait(
        draft: MpesaStkInitiateDraft(
          purpose: 'invoice',
          purposeRef: invId,
          amount: amtInt,
          phone: normalized,
          clientRequestId: 'stk_${DateTime.now().millisecondsSinceEpoch}',
        ),
        timeout: timeout,
        onTick: (tick) {
          state = state.copyWith(mpesaLastPayment: tick);
        },
      );

      state = state.copyWith(mpesaLastPayment: p);

      if (p.isFailed) {
        final msg = (p.resultDesc ?? '').trim();
        SnackService.showError(msg.isEmpty ? 'M-Pesa payment failed' : msg);
        state = state.copyWith(payingMpesa: false);
        return false;
      }

      if (!p.isSuccess) {
        SnackService.showError(
          'Payment still pending. Tap refresh to check status.',
        );
        state = state.copyWith(payingMpesa: false);
        return false;
      }

      final z = (p.zohoSyncStatus ?? '').trim().toLowerCase();
      SnackService.showSuccess(
        z == 'success'
            ? 'Payment received'
            : 'Payment received. Syncing to Zoho…',
      );

      // ✅ reload payments + invoice summary/balance
      await refresh();

      state = state.copyWith(payingMpesa: false);
      return true;
    } catch (e) {
      state = state.copyWith(payingMpesa: false, error: _err(e));
      SnackService.showError('Failed to initiate M-Pesa STK');
      return false;
    }
  }

  // ───────────────────────── Defaults seeding (typed, NO contact fetch) ─────────────────────────

  /// Only seeds pending amount from invoice summary (balance).
  /// Phone MUST be seeded via [seedFromInvoiceContext] from the parent screen.
  Future<void> ensureSeededDefaults() async {
    if (state.busy) return;
    if (state.isEditing) return;
    if (state.defaultsSeeded) return;

    final InvoiceBalanceSummary? summary = state.invoiceSummary;
    final pending = _pendingFromSummary(summary);

    if (pending != null && pending > 0) {
      // store for helper text
      state = state.copyWith(pendingAmount: pending);

      // seed into draft only if draft is still empty
      if (state.paymentDraft.amount <= 0) {
        patchDraft(amount: pending);
      }
    }

    // Mark seeded only when we had a summary to seed from.
    state = state.copyWith(defaultsSeeded: summary != null);
  }

  static num? _pendingFromSummary(InvoiceBalanceSummary? s) {
    if (s == null) return null;
    final b = s.balance;
    if (b == null) return null;
    if (!b.isFinite) return null;
    return b <= 0 ? null : b;
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
