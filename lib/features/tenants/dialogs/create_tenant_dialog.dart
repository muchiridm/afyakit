import 'package:afyakit/features/tenants/models/tenant_dtos.dart';
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
  final _ownerUid = TextEditingController();
  final _ownerEmail = TextEditingController();
  final _seedAdmins = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _primary.dispose();
    _logo.dispose();
    _ownerUid.dispose();
    _ownerEmail.dispose();
    _seedAdmins.dispose();
    super.dispose();
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
            const SizedBox(height: 8),
            TextField(
              controller: _ownerUid,
              decoration: const InputDecoration(
                labelText: 'Owner UID (optional)',
              ),
            ),
            TextField(
              controller: _ownerEmail,
              decoration: const InputDecoration(
                labelText: 'Owner email (optional)',
              ),
            ),
            TextField(
              controller: _seedAdmins,
              decoration: const InputDecoration(
                labelText: 'Seed admin UIDs (comma separated, optional)',
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
        ElevatedButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            final seeds = _seedAdmins.text
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toSet()
                .toList();
            Navigator.pop(
              context,
              CreateTenantPayload(
                displayName: _name.text.trim(),
                slug: _slug.text.trim().isEmpty ? null : _slug.text.trim(),
                primaryColor: _primary.text.trim().isEmpty
                    ? '#1565C0'
                    : _primary.text.trim(),
                logoPath: _logo.text.trim().isEmpty ? null : _logo.text.trim(),
                ownerUid: _ownerUid.text.trim().isEmpty
                    ? null
                    : _ownerUid.text.trim(),
                ownerEmail: _ownerEmail.text.trim().isEmpty
                    ? null
                    : _ownerEmail.text.trim(),
                seedAdminUids: seeds,
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
