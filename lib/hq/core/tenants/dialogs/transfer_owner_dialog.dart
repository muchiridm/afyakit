import 'package:flutter/material.dart';

/// Simple dumb dialog that returns a string target (email or UID).
class TransferOwnerDialog extends StatefulWidget {
  const TransferOwnerDialog({super.key});

  @override
  State<TransferOwnerDialog> createState() => _TransferOwnerDialogState();
}

class _TransferOwnerDialogState extends State<TransferOwnerDialog> {
  final _target = TextEditingController();

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _target.text.trim();
    if (v.isEmpty) return;
    Navigator.pop(context, v); // controller decides email vs uid
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transfer Ownership'),
      content: TextField(
        controller: _target,
        decoration: const InputDecoration(
          labelText: 'New owner (email or UID)',
          hintText: 'jane@acme.com or 123456...',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Transfer')),
      ],
    );
  }
}
