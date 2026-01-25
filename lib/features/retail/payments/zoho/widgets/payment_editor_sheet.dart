import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/payments/zoho/controllers/payment_controller.dart';
import 'package:afyakit/features/retail/payments/zoho/controllers/payment_state.dart';
import 'package:afyakit/features/retail/shared/widgets/sales_formatters.dart';

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
  late final TextEditingController _refCtl;
  late final TextEditingController _descCtl;

  String? _lastEditingPaymentId;

  @override
  void initState() {
    super.initState();
    final s = ref.read(paymentControllerProvider(widget.invoiceId));
    _seedFromState(s);
    _lastEditingPaymentId = s.editingPaymentId;
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _dateCtl.dispose();
    _modeCtl.dispose();
    _refCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  void _seedFromState(PaymentState s) {
    _amountCtl = TextEditingController(text: s.paymentDraft.amount.toString());
    _dateCtl = TextEditingController(text: ymd.format(s.paymentDraft.date));
    _modeCtl = TextEditingController(text: (s.paymentDraft.mode ?? '').trim());
    _refCtl = TextEditingController(
      text: (s.paymentDraft.referenceNumber ?? '').trim(),
    );
    _descCtl = TextEditingController(
      text: (s.paymentDraft.description ?? '').trim(),
    );
  }

  void _resetControllersFromDraft(PaymentState s) {
    _amountCtl.text = s.paymentDraft.amount.toString();
    _dateCtl.text = ymd.format(s.paymentDraft.date);
    _modeCtl.text = (s.paymentDraft.mode ?? '').trim();
    _refCtl.text = (s.paymentDraft.referenceNumber ?? '').trim();
    _descCtl.text = (s.paymentDraft.description ?? '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(paymentControllerProvider(widget.invoiceId));
    final ctl = ref.read(paymentControllerProvider(widget.invoiceId).notifier);

    if (_lastEditingPaymentId != s.editingPaymentId) {
      _lastEditingPaymentId = s.editingPaymentId;
      _resetControllersFromDraft(s);
    }

    final isEdit = (s.editingPaymentId ?? '').trim().isNotEmpty;

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
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _amountCtl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => ctl.patchDraft(amount: num.tryParse(v.trim())),
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
            controller: _refCtl,
            decoration: const InputDecoration(
              labelText: 'Reference number (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => ctl.patchDraft(referenceNumber: v),
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
}
