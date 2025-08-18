// lib/hq/tenants/dialogs/edit_tenant_dialog.dart
import 'package:afyakit/tenants/models/tenant_dtos.dart';
import 'package:flutter/material.dart';

class EditTenantDialog extends StatefulWidget {
  const EditTenantDialog({
    super.key,
    required this.initialDisplayName,
    required this.initialPrimaryColor,
    required this.initialLogoPath,
  });

  final String initialDisplayName;
  final String initialPrimaryColor;
  final String? initialLogoPath;

  @override
  State<EditTenantDialog> createState() => _EditTenantDialogState();
}

class _EditTenantDialogState extends State<EditTenantDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialDisplayName,
  );
  late final TextEditingController _primary = TextEditingController(
    text: widget.initialPrimaryColor,
  );
  late final TextEditingController _logo = TextEditingController(
    text: widget.initialLogoPath ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _primary.dispose();
    _logo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Tenant'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            TextField(
              controller: _primary,
              decoration: const InputDecoration(
                labelText: 'Primary color (#HEX)',
              ),
            ),
            TextField(
              controller: _logo,
              decoration: const InputDecoration(labelText: 'Logo path'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              EditTenantPayload(
                displayName: _name.text.trim().isEmpty
                    ? null
                    : _name.text.trim(),
                primaryColor: _primary.text.trim().isEmpty
                    ? null
                    : _primary.text.trim(),
                logoPath: _logo.text.trim().isEmpty ? null : _logo.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
