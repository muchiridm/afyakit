// lib/features/retail/payments/widgets/payment_editor_sheet.dart

import 'package:afyakit/features/retail/payments/controllers/payment_controller.dart';
import 'package:afyakit/features/retail/shared/sales_doc/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  ConsumerState<PaymentEditorSheet> createState() {
    return _PaymentEditorSheetState();
  }
}

class _PaymentEditorSheetState extends ConsumerState<PaymentEditorSheet> {
  late final TextEditingController _amountCtl;
  late final TextEditingController _dateCtl;
  late final TextEditingController _modeCtl;
  late final TextEditingController _referenceCtl;
  late final TextEditingController _descriptionCtl;

  String? _lastEditingPaymentId;
  bool _amountDirty = false;

  @override
  void initState() {
    super.initState();

    final PaymentState state = ref.read(
      paymentControllerProvider(widget.invoiceId),
    );

    _seedControllers(state);
    _lastEditingPaymentId = state.editingPaymentId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ref
          .read(paymentControllerProvider(widget.invoiceId).notifier)
          .ensureSeededDefaults();
    });
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _dateCtl.dispose();
    _modeCtl.dispose();
    _referenceCtl.dispose();
    _descriptionCtl.dispose();
    super.dispose();
  }

  void _seedControllers(PaymentState state) {
    final draft = state.paymentDraft;

    _amountCtl = TextEditingController(text: _formatAmount(draft.amount));
    _dateCtl = TextEditingController(text: ymd.format(draft.date));
    _modeCtl = TextEditingController(text: (draft.mode ?? '').trim());
    _referenceCtl = TextEditingController(text: (draft.reference ?? '').trim());
    _descriptionCtl = TextEditingController(
      text: (draft.description ?? '').trim(),
    );
  }

  void _resetControllers(PaymentState state) {
    final draft = state.paymentDraft;

    _amountDirty = false;

    _amountCtl.text = _formatAmount(draft.amount);
    _dateCtl.text = ymd.format(draft.date);
    _modeCtl.text = (draft.mode ?? '').trim();
    _referenceCtl.text = (draft.reference ?? '').trim();
    _descriptionCtl.text = (draft.description ?? '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final PaymentState state = ref.watch(
      paymentControllerProvider(widget.invoiceId),
    );

    final PaymentController controller = ref.read(
      paymentControllerProvider(widget.invoiceId).notifier,
    );

    if (_lastEditingPaymentId != state.editingPaymentId) {
      _lastEditingPaymentId = state.editingPaymentId;
      _resetControllers(state);
    }

    _maybeAutofillAmount(state);

    final bool isEdit = state.isEditing;
    final bool busy = state.busy;

    final num? pending = _validPending(state.pendingAmount);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Header(
              title: isEdit ? 'Edit payment' : 'Record payment',
              busy: busy,
              onClose: () => Navigator.pop(context),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtl,
              enabled: !busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                border: const OutlineInputBorder(),
                helperText: pending == null ? null : 'Pending: $pending',
                suffixIcon: pending == null || isEdit || busy
                    ? null
                    : IconButton(
                        tooltip: 'Use pending amount',
                        onPressed: () {
                          _amountDirty = false;
                          _amountCtl.text = _formatAmount(pending);
                          controller.patchDraft(amount: pending);
                        },
                        icon: const Icon(Icons.call_made_outlined),
                      ),
              ),
              onChanged: (String value) {
                _amountDirty = true;
                controller.patchDraft(amount: _parseAmount(value));
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _dateCtl,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Date (YYYY-MM-DD)',
                border: OutlineInputBorder(),
              ),
              onChanged: (String value) {
                final DateTime? parsed = DateTime.tryParse(value.trim());
                if (parsed == null) return;

                controller.patchDraft(
                  date: DateTime(parsed.year, parsed.month, parsed.day),
                );
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _modeCtl,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Mode',
                hintText: 'Cash, M-Pesa, Bank Transfer...',
                border: OutlineInputBorder(),
              ),
              onChanged: (String value) {
                controller.patchDraft(mode: value);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _referenceCtl,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Reference',
                hintText: 'M-Pesa receipt, bank ref, cheque no...',
                border: OutlineInputBorder(),
              ),
              onChanged: (String value) {
                controller.patchDraft(reference: value);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionCtl,
              enabled: !busy,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              onChanged: (String value) {
                controller.patchDraft(description: value);
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy
                        ? null
                        : () {
                            controller.cancelPaymentEdit();
                            Navigator.pop(context);
                          },
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            final bool ok = await controller.savePayment();

                            if (!ok) return;
                            if (!context.mounted) return;

                            Navigator.pop(context);
                          },
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(busy ? 'Saving…' : 'Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _maybeAutofillAmount(PaymentState state) {
    if (state.isEditing) return;
    if (_amountDirty) return;

    final num amount = state.paymentDraft.amount;
    if (amount <= 0) return;

    final String next = _formatAmount(amount);
    if (_amountCtl.text.trim() == next) return;

    _amountCtl.text = next;
  }

  static num? _parseAmount(String value) {
    final String text = value.trim();
    if (text.isEmpty) return null;

    return num.tryParse(text);
  }

  static num? _validPending(num? value) {
    if (value == null) return null;
    if (!value.isFinite) return null;
    if (value <= 0) return null;

    return value;
  }

  static String _formatAmount(num value) {
    if (!value.isFinite) return '0';

    final num safe = value < 0 ? 0 : value;

    if (safe == safe.roundToDouble()) {
      return safe.toInt().toString();
    }

    return safe.toStringAsFixed(2);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.busy,
    required this.onClose,
  });

  final String title;
  final bool busy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: busy ? null : onClose,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}
