// lib/features/retail/sared/sales_doc/dialogs.dart
// (typo note: "sared" looks unintended — but leaving your path as-is)

import 'package:afyakit/shared/services/dialog_service.dart';
import 'package:flutter/material.dart';

class SalesDocDialogs {
  SalesDocDialogs._();

  static Future<bool> confirm(
    BuildContext? context, {
    required String title,
    required String message,
    String cancelLabel = 'Cancel',
    String okLabel = 'OK',
    bool danger = false,
    bool barrierDismissible = false,
  }) {
    return DialogService.confirm(
      context: context,
      title: title,
      content: message,
      cancelText: cancelLabel,
      confirmText: okLabel,
      confirmColor: danger ? Colors.redAccent : Colors.blue,
      barrierDismissible: barrierDismissible,
    );
  }

  static Future<bool> confirmDelete(
    BuildContext? context, {
    required String thing,
    String message = 'This will delete it permanently.',
  }) {
    return confirm(
      context,
      title: 'Delete $thing?',
      message: message,
      cancelLabel: 'Cancel',
      okLabel: 'Delete',
      danger: true,
      barrierDismissible: false,
    );
  }

  static Future<bool> confirmDiscardChanges(BuildContext? context) {
    return confirm(
      context,
      title: 'Discard changes?',
      message: 'Your edits will be lost.',
      cancelLabel: 'Keep editing',
      okLabel: 'Discard',
      danger: true,
      barrierDismissible: false,
    );
  }

  static Future<bool> confirmDiscardCheckout(BuildContext? context) {
    return confirm(
      context,
      title: 'Discard checkout?',
      message: 'This will clear the cart and remove all items.',
      cancelLabel: 'Keep',
      okLabel: 'Discard',
      danger: true,
      barrierDismissible: false,
    );
  }

  static Future<bool> confirmClearAll(BuildContext? context) {
    return confirm(
      context,
      title: 'Clear everything?',
      message: 'This will remove all items from the cart and draft.',
      cancelLabel: 'Cancel',
      okLabel: 'Clear',
      danger: true,
      barrierDismissible: false,
    );
  }

  static Future<String?> editText(
    BuildContext context, {
    required String title,
    required String initial,
    String okLabel = 'Save',
    String cancelLabel = 'Cancel',
    bool isMultiline = false,
  }) {
    return DialogService.prompt(
      context: context,
      title: title,
      initialValue: initial,
      confirmText: okLabel,
      cancelText: cancelLabel,
      isMultiline: isMultiline,
    );
  }

  static Future<SalesDocLineEditResult?> editLine(
    BuildContext context, {
    required String initialName,
    String? initialDescription,
    required int initialQty,
    required num initialRate,
    required bool enableRate,
  }) {
    return showDialog<SalesDocLineEditResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LineEditDialog(
        initialName: initialName,
        initialDescription: initialDescription ?? '',
        initialQty: initialQty,
        initialRate: initialRate,
        enableRate: enableRate,
      ),
    );
  }
}

class SalesDocLineEditResult {
  const SalesDocLineEditResult({
    required this.name,
    required this.description,
    required this.qty,
    required this.rate,
  });

  final String name;
  final String description; // keep non-null for easier callers
  final int qty;
  final num rate;
}

class _LineEditDialog extends StatefulWidget {
  const _LineEditDialog({
    required this.initialName,
    required this.initialDescription,
    required this.initialQty,
    required this.initialRate,
    required this.enableRate,
  });

  final String initialName;
  final String initialDescription;
  final int initialQty;
  final num initialRate;
  final bool enableRate;

  @override
  State<_LineEditDialog> createState() => _LineEditDialogState();
}

class _LineEditDialogState extends State<_LineEditDialog> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _descCtl;
  late final TextEditingController _qtyCtl;
  late final TextEditingController _rateCtl;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.initialName);
    _descCtl = TextEditingController(text: widget.initialDescription);
    _qtyCtl = TextEditingController(text: widget.initialQty.toString());
    _rateCtl = TextEditingController(text: widget.initialRate.toString());
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    _qtyCtl.dispose();
    _rateCtl.dispose();
    super.dispose();
  }

  static String _cleanNum(String s) => s.trim().replaceAll(',', '');

  int _parseQty(String raw) {
    final n = int.tryParse(_cleanNum(raw));
    final v = n ?? widget.initialQty;
    return v < 1 ? 1 : v;
  }

  num _parseRate(String raw) {
    if (!widget.enableRate) return widget.initialRate;
    final n = num.tryParse(_cleanNum(raw));
    if (n == null || n.isNaN || n.isInfinite) return widget.initialRate;
    return n < 0 ? 0 : n;
  }

  void _submit() {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) return;

    final desc = _descCtl.text.trim(); // can be empty string
    final qty = _parseQty(_qtyCtl.text);
    final rate = _parseRate(_rateCtl.text);

    Navigator.pop(
      context,
      SalesDocLineEditResult(
        name: name,
        description: desc,
        qty: qty,
        rate: rate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit item'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Item',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtl,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: widget.enableRate
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onSubmitted: (_) {
                      if (!widget.enableRate) _submit();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _rateCtl,
                    enabled: widget.enableRate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Rate',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
