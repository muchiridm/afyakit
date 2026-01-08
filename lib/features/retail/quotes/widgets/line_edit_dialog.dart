// lib/features/retail/quotes/widgets/line_edit_dialog.dart

import 'package:flutter/material.dart';

class LineEditResult {
  const LineEditResult({required this.qty, required this.rate});
  final int qty;
  final num rate;
}

class LineEditDialog extends StatefulWidget {
  const LineEditDialog({super.key, required this.qty, required this.rate});

  final int qty;
  final num rate;

  @override
  State<LineEditDialog> createState() => _LineEditDialogState();
}

class _LineEditDialogState extends State<LineEditDialog> {
  late final TextEditingController _qtyCtl;
  late final TextEditingController _rateCtl;

  @override
  void initState() {
    super.initState();
    _qtyCtl = TextEditingController(text: widget.qty.toString());
    _rateCtl = TextEditingController(text: widget.rate.toString());
  }

  @override
  void dispose() {
    _qtyCtl.dispose();
    _rateCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit line'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _qtyCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rateCtl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Rate'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final q0 = int.tryParse(_qtyCtl.text.trim()) ?? widget.qty;
            final q = q0 < 1 ? 1 : q0;

            final r0 = num.tryParse(_rateCtl.text.trim()) ?? widget.rate;
            final r = r0 < 0 ? 0 : r0;

            Navigator.of(context).pop(LineEditResult(qty: q, rate: r));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
