// lib/features/retail/payments/zoho/controllers/payment_controller.dart

import 'package:afyakit/features/retail/payments/zoho/controllers/payment_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/shared/models/zoho_invoice_payment.dart';
import 'package:afyakit/features/retail/shared/models/zoho_payment_draft.dart';
import 'package:afyakit/features/retail/payments/zoho/services/zoho_payments_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';

import 'package:afyakit/features/retail/payments/mpesa/models/mpesa_stk_draft.dart';
import 'package:afyakit/features/retail/payments/mpesa/services/mpesa_service.dart';

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
      clearMpesaLastPayment: true,

      // ✅ important: allow re-seeding on a fresh open/load
      clearPendingAmount: true,
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

      // ✅ seed AFTER summary arrives
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

      // ✅ allow re-seeding if summary changed (optional, but useful)
      clearPendingAmount: true,
      defaultsSeeded: false,
    );

    try {
      final svc = await _ref.read(zohoPaymentsServiceProvider.future);
      final payRes = await svc.listInvoicePaymentsWithBalance(id);

      state = state.copyWith(
        loadingPayments: false,
        payments: payRes.payments,
        invoiceSummary: payRes.invoice,
      );

      // ✅ seed AFTER summary arrives
      // ignore: discarded_futures
      ensureSeededDefaults();
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

  // ───────────────────────── Actions (Zoho manual) ─────────────────────────

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

        // ✅ re-seed after save (new pending amount)
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
      return true;
    } catch (e) {
      state = state.copyWith(deletingPayment: false, error: _err(e));
      SnackService.showError('Failed to delete payment');
      return false;
    }
  }

  // ───────────────────────── Actions (M-Pesa STK) ─────────────────────────

  Future<bool> payViaMpesaStk({
    required String phone,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (_busy) return false;

    final invId = invoiceId;
    if (invId.isEmpty) {
      SnackService.showError('Missing invoice id');
      return false;
    }

    // Use the amount currently in the draft
    final draft = state.paymentDraft.copyWith(invoiceId: invId).withDateOnly();
    if (!_validateDraft(draft)) return false;

    final amtInt = draft.amount.toInt();
    if (amtInt <= 0) {
      SnackService.showError('Amount must be greater than 0');
      return false;
    }

    state = state.copyWith(
      payingMpesa: true,
      loadingPayments: true,
      clearError: true,
      clearMpesaLastPayment: true,
    );

    try {
      final mpesaSvc = await _ref.read(mpesaServiceProvider.future);

      final p = await mpesaSvc.initiateAndWait(
        draft: MpesaStkInitiateDraft(
          purpose: 'invoice',
          purposeRef: invId, // MUST be Zoho invoice_id
          amount: amtInt,
          phone: phone.trim(),
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

        state = state.copyWith(payingMpesa: false, loadingPayments: false);
        return false;
      }

      if (!p.isSuccess) {
        // Timeout/pending. Give user a way to refresh later.
        SnackService.showError(
          'Payment still pending. Tap refresh to check status.',
        );
        state = state.copyWith(payingMpesa: false, loadingPayments: false);
        return false;
      }

      // STK success
      final z = (p.zohoSyncStatus ?? '').trim().toLowerCase();
      if (z == 'success') {
        SnackService.showSuccess('Payment received');
      } else {
        SnackService.showSuccess('Payment received. Syncing to Zoho…');
      }

      // Refresh Zoho invoice payments/balance
      await refresh();

      state = state.copyWith(payingMpesa: false, loadingPayments: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        payingMpesa: false,
        loadingPayments: false,
        error: _err(e),
      );
      SnackService.showError('Failed to initiate M-Pesa STK');
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

  Future<void> ensureSeededDefaults() async {
    // Don’t fight the user or editing flows.
    if (state.busy) return;
    if (state.isEditing) return;
    if (state.defaultsSeeded) return;

    // We can ONLY seed after invoiceSummary is available.
    final summary = state.invoiceSummary;
    if (summary == null) return;

    final pending = _pendingFromSummary(summary);

    // If we still can't resolve pending, don't lock defaultsSeeded.
    if (pending == null || pending <= 0) {
      return;
    }

    // Seed the draft amount only if draft still zero-ish.
    final draftAmt = state.paymentDraft.amount;
    final shouldSeedAmount = (draftAmt <= 0);

    if (shouldSeedAmount) {
      patchDraft(amount: pending);
    }

    // Persist pending in state for helper text + "use pending" button.
    state = state.copyWith(pendingAmount: pending, defaultsSeeded: true);
  }

  // Tries common field names without tying you to a specific DTO shape.
  // (This compiles even if InvoiceBalanceSummary changes.)
  static num? _pendingFromSummary(Object summary) {
    num? pick(Object? v) =>
        v is num ? v : (v is String ? num.tryParse(v) : null);

    try {
      final d = summary as dynamic;

      // Try the most common shapes first
      final cands = <Object?>[
        () {
          try {
            return d.balanceDue;
          } catch (_) {
            return null;
          }
        }(),
        () {
          try {
            return d.balance_due;
          } catch (_) {
            return null;
          }
        }(),
        () {
          try {
            return d.balance;
          } catch (_) {
            return null;
          }
        }(),
        () {
          try {
            return d.amountDue;
          } catch (_) {
            return null;
          }
        }(),
        () {
          try {
            return d.amount_due;
          } catch (_) {
            return null;
          }
        }(),
        () {
          try {
            return d.pendingAmount;
          } catch (_) {
            return null;
          }
        }(),
        () {
          try {
            return d.pending_amount;
          } catch (_) {
            return null;
          }
        }(),
        () {
          try {
            return d.outstanding;
          } catch (_) {
            return null;
          }
        }(),
      ];

      for (final v in cands) {
        final n = pick(v);
        if (n != null && n.isFinite) return n;
      }
    } catch (_) {
      // ignore
    }

    return null;
  }

  static String _err(Object e) {
    final s = e.toString().trim();
    return s.isEmpty ? 'Unknown error' : s;
  }
}
