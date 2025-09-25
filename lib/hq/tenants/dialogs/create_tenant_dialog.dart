import 'package:afyakit/hq/tenants/models/tenant_payloads.dart';
import 'package:flutter/material.dart';

class CreateTenantDialog extends StatefulWidget {
  const CreateTenantDialog({super.key});

  @override
  State<CreateTenantDialog> createState() => _CreateTenantDialogState();
}

class _CreateTenantDialogState extends State<CreateTenantDialog> {
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _primary = TextEditingController(text: '#1565C0');
  final _logo = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _primary.dispose();
    _logo.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      CreateTenantPayload(
        displayName: _name.text.trim(),
        primaryColor: _primary.text.trim().isEmpty
            ? '#1565C0'
            : _primary.text.trim(),
        slug: _slug.text.trim().isEmpty ? null : _slug.text.trim(),
        logoPath: _logo.text.trim().isEmpty ? null : _logo.text.trim(),
        // ownerUid / ownerEmail / seedAdminUids intentionally omitted
        // (backend create does not accept them; controller ignores if present)
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Tenant'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Display name *'),
            ),
            TextField(
              controller: _slug,
              decoration: const InputDecoration(labelText: 'Slug (optional)'),
            ),
            TextField(
              controller: _primary,
              decoration: const InputDecoration(
                labelText: 'Primary color (#HEX)',
              ),
            ),
            TextField(
              controller: _logo,
              decoration: const InputDecoration(
                labelText: 'Logo path (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}
