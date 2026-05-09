// lib/features/retail/payments/zoho/widgets/payment_editor_sheet.dart

import 'package:afyakit/features/retail/mpesa/models/mpesa_payment.dart';
import 'package:afyakit/features/retail/payments/controllers/payment_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/shared/sales_doc/helpers.dart';
import 'package:afyakit/features/retail/payments/controllers/payment_controller.dart';

class PaymentEditorSheet extends ConsumerStatefulWidget {
  const PaymentEditorSheet({super.key, required this.invoiceId});

  final String invoiceId;

  static Future<void> open(BuildContext context, {required String invoiceId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PaymentEditorSheet(invoiceId: invoiceId),
    );
  }

  @override
  ConsumerState<PaymentEditorSheet> createState() => _PaymentEditorSheetState();
}

class _PaymentEditorSheetState extends ConsumerState<PaymentEditorSheet> {
  late final TextEditingController _amountCtl;
  late final TextEditingController _dateCtl;
  late final TextEditingController _modeCtl;
  late final TextEditingController _descCtl;

  // ✅ NEW: phone input lives in the sheet (no dialog)
  late final TextEditingController _phoneCtl;

  ProviderSubscription<PaymentState>? _sub;

  String? _lastEditingPaymentId;

  bool _amountDirty = false;
  bool _phoneDirty = false;

  @override
  void initState() {
    super.initState();

    final s = ref.read(paymentControllerProvider(widget.invoiceId));
    _seedFromState(s);
    _lastEditingPaymentId = s.editingPaymentId;

    // ✅ Riverpod-safe listener for initState
    _sub = ref.listenManual<PaymentState>(
      paymentControllerProvider(widget.invoiceId),
      (prev, next) {
        if (!mounted) return;

        // ---- Amount auto-fill (pending) ----
        final prevAmt = prev?.paymentDraft.amount ?? 0;
        final nextAmt = next.paymentDraft.amount;
        final becameNonZero = (prevAmt <= 0) && (nextAmt > 0);

        if (!next.isEditing && !_amountDirty && becameNonZero) {
          _amountCtl.text = _fmtAmount(nextAmt);
        }

        // ---- Phone auto-fill (suggested) ----
        final prevPhone = (prev?.suggestedMpesaPhone ?? '').trim();
        final nextPhone = (next.suggestedMpesaPhone ?? '').trim();

        final becameAvailable = prevPhone.isEmpty && nextPhone.isNotEmpty;

        if (!_phoneDirty && becameAvailable) {
          _phoneCtl.text = nextPhone;
        }
      },
    );

    // ✅ Kick seeding (pending amount + suggested phone)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(paymentControllerProvider(widget.invoiceId).notifier)
          .ensureSeededDefaults();
    });
  }

  @override
  void dispose() {
    _sub?.close();
    _amountCtl.dispose();
    _dateCtl.dispose();
    _modeCtl.dispose();
    _descCtl.dispose();
    _phoneCtl.dispose();
    super.dispose();
  }

  void _seedFromState(PaymentState s) {
    _amountCtl = TextEditingController(text: _fmtAmount(s.paymentDraft.amount));
    _dateCtl = TextEditingController(text: ymd.format(s.paymentDraft.date));
    _modeCtl = TextEditingController(text: (s.paymentDraft.mode ?? '').trim());
    _descCtl = TextEditingController(
      text: (s.paymentDraft.description ?? '').trim(),
    );

    // ✅ seed phone from state (if already known)
    _phoneCtl = TextEditingController(
      text: (s.suggestedMpesaPhone ?? '').trim(),
    );
  }

  void _resetControllersFromDraft(PaymentState s) {
    _amountDirty = false;
    _phoneDirty = false;

    _amountCtl.text = _fmtAmount(s.paymentDraft.amount);
    _dateCtl.text = ymd.format(s.paymentDraft.date);
    _modeCtl.text = (s.paymentDraft.mode ?? '').trim();
    _descCtl.text = (s.paymentDraft.description ?? '').trim();
    _phoneCtl.text = (s.suggestedMpesaPhone ?? '').trim();
  }

  static String _fmtAmount(num v) {
    if (v.isNaN || v.isInfinite) return '0';
    final n = v < 0 ? 0 : v;
    return n.toString();
  }

  static num? _parseAmount(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return num.tryParse(t);
  }

  static String _normalizePhone(String raw) {
    // keep it minimal: trim only. backend/service can normalize further.
    return raw.trim();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(paymentControllerProvider(widget.invoiceId));
    final ctl = ref.read(paymentControllerProvider(widget.invoiceId).notifier);

    if (_lastEditingPaymentId != s.editingPaymentId) {
      _lastEditingPaymentId = s.editingPaymentId;
      _resetControllersFromDraft(s);
    }

    final isEdit = s.isEditing;

    final pending = (s.pendingAmount ?? 0);
    final hasPending = pending > 0;

    const showMpesa = true;

    final phone = _normalizePhone(_phoneCtl.text);
    final hasPhone = phone.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isEdit ? 'Edit payment' : 'Record payment',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: s.busy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _amountCtl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              border: const OutlineInputBorder(),
              helperText: hasPending ? 'Pending: $pending' : null,
              suffixIcon: (!s.busy && hasPending && !isEdit)
                  ? IconButton(
                      tooltip: 'Use pending amount',
                      onPressed: () {
                        _amountDirty = false;
                        _amountCtl.text = _fmtAmount(pending);
                        ctl.patchDraft(amount: pending);
                      },
                      icon: const Icon(Icons.call_made_outlined),
                    )
                  : null,
            ),
            onChanged: (v) {
              _amountDirty = true;
              ctl.patchDraft(amount: _parseAmount(v));
            },
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _dateCtl,
            decoration: const InputDecoration(
              labelText: 'Date (YYYY-MM-DD)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              final dt = DateTime.tryParse(v.trim());
              if (dt != null) ctl.patchDraft(date: dt);
            },
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _modeCtl,
            decoration: const InputDecoration(
              labelText: 'Mode (Cash, Mpesa, Bank...)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => ctl.patchDraft(mode: v),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _descCtl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => ctl.patchDraft(description: v),
          ),
          const SizedBox(height: 12),

          // ✅ NEW: M-Pesa phone field inside the sheet (no dialog)
          if (showMpesa) ...[
            TextField(
              controller: _phoneCtl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'M-Pesa phone',
                border: const OutlineInputBorder(),
                hintText: '07XXXXXXXX or 2547XXXXXXXX',
                helperText: (s.suggestedMpesaPhone ?? '').trim().isNotEmpty
                    ? 'Suggested phone loaded'
                    : 'Enter the phone number to receive the STK prompt',
              ),
              onChanged: (_) {
                _phoneDirty = true;
              },
            ),
            const SizedBox(height: 12),
          ],

          if (s.mpesaLastPayment != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _mpesaStatusLabel(s.mpesaLastPayment!),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: s.busy
                      ? null
                      : () {
                          ctl.cancelPaymentEdit();
                          Navigator.pop(context);
                        },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),

              if (showMpesa) ...[
                Expanded(
                  child: FilledButton.icon(
                    icon: s.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.phone_android),
                    label: Text(s.busy ? 'Processing…' : 'Pay via M-Pesa'),
                    onPressed: (s.busy || !hasPhone)
                        ? null
                        : () async {
                            final ok = await ctl.payViaMpesaStk(phone: phone);
                            if (!ok) return;
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          },
                  ),
                ),
                const SizedBox(width: 12),
              ],

              Expanded(
                child: FilledButton.icon(
                  icon: s.busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(s.busy ? 'Saving…' : 'Save'),
                  onPressed: s.busy
                      ? null
                      : () async {
                          final ok = await ctl.savePayment();
                          if (!ok) return;
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _mpesaStatusLabel(MpesaPayment p) {
    final s = p.status.trim().toLowerCase();

    if (s == 'created') return 'M-Pesa: created (waiting to initiate)';
    if (s == 'stk_initiated') return 'M-Pesa: waiting for PIN on phone…';
    if (s == 'stk_failed') {
      final msg = (p.resultDesc ?? '').trim();
      return msg.isEmpty ? 'M-Pesa: failed' : 'M-Pesa: failed — $msg';
    }
    if (s == 'stk_success') {
      final z = (p.zohoSyncStatus ?? '').trim().toLowerCase();
      if (z == 'success') return 'M-Pesa: success (synced to Zoho)';
      if (z == 'failed') {
        final err = (p.zohoSyncError ?? '').trim();
        return err.isEmpty
            ? 'M-Pesa: success (Zoho sync failed)'
            : 'M-Pesa: success (Zoho sync failed) — $err';
      }
      return 'M-Pesa: success (syncing to Zoho…)';
    }

    return 'M-Pesa: $s';
  }
}
