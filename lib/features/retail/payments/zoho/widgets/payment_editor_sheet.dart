// lib/features/retail/payments/zoho/widgets/payment_editor_sheet.dart

import 'package:afyakit/features/retail/payments/mpesa/models/mpesa_payment.dart';
import 'package:afyakit/features/retail/payments/zoho/controllers/payment_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/shared/sales_doc/helpers.dart';
import 'package:afyakit/features/retail/payments/zoho/controllers/payment_controller.dart';

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

  ProviderSubscription<PaymentState>? _sub;

  String? _lastEditingPaymentId;
  bool _amountDirty = false;

  @override
  void initState() {
    super.initState();

    final s = ref.read(paymentControllerProvider(widget.invoiceId));
    _seedFromState(s);
    _lastEditingPaymentId = s.editingPaymentId;

    // ✅ Riverpod-safe listener for initState:
    _sub = ref.listenManual<PaymentState>(
      paymentControllerProvider(widget.invoiceId),
      (prev, next) {
        if (!mounted) return;

        final prevAmt = prev?.paymentDraft.amount ?? 0;
        final nextAmt = next.paymentDraft.amount;

        final becameNonZero = (prevAmt <= 0) && (nextAmt > 0);

        // only auto-fill if user hasn't typed and we’re not editing
        if (!next.isEditing && !_amountDirty && becameNonZero) {
          _amountCtl.text = _fmtAmount(nextAmt);
        }
      },
    );

    // ✅ kick seeding
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
    super.dispose();
  }

  void _seedFromState(PaymentState s) {
    _amountCtl = TextEditingController(text: _fmtAmount(s.paymentDraft.amount));
    _dateCtl = TextEditingController(text: ymd.format(s.paymentDraft.date));
    _modeCtl = TextEditingController(text: (s.paymentDraft.mode ?? '').trim());
    _descCtl = TextEditingController(
      text: (s.paymentDraft.description ?? '').trim(),
    );
  }

  void _resetControllersFromDraft(PaymentState s) {
    _amountDirty = false;
    _amountCtl.text = _fmtAmount(s.paymentDraft.amount);
    _dateCtl.text = ymd.format(s.paymentDraft.date);
    _modeCtl.text = (s.paymentDraft.mode ?? '').trim();
    _descCtl.text = (s.paymentDraft.description ?? '').trim();
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

  Future<String?> _promptPhone(
    BuildContext context, {
    String? initialPhone,
  }) async {
    final ctl = TextEditingController(text: (initialPhone ?? '').trim());
    String? out;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('M-Pesa phone number'),
          content: TextField(
            controller: ctl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: '07XXXXXXXX or 2547XXXXXXXX',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final v = ctl.text.trim();
                out = v.isEmpty ? null : v;
                Navigator.pop(ctx);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    ctl.dispose();
    return out;
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
                    onPressed: s.busy
                        ? null
                        : () async {
                            final phone = await _promptPhone(
                              context,
                              initialPhone: s.suggestedMpesaPhone,
                            );
                            if (phone == null) return;

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
