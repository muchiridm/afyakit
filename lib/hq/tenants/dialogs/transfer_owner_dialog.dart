// lib/hq/tenants/dialogs/transfer_owner_dialog.dart
import 'package:flutter/material.dart';

class TransferOwnerDialog extends StatefulWidget {
  const TransferOwnerDialog({super.key});

  @override
  State<TransferOwnerDialog> createState() => _TransferOwnerDialogState();
}

class _TransferOwnerDialogState extends State<TransferOwnerDialog> {
  final _uid = TextEditingController();

  @override
  void dispose() {
    _uid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transfer Ownership'),
      content: TextField(
        controller: _uid,
        decoration: const InputDecoration(labelText: 'New owner UID'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _uid.text.trim()),
          child: const Text('Transfer'),
        ),
      ],
    );
  }
}
