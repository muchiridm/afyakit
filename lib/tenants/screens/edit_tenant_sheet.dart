// lib/tenants/screens/edit_tenant_sheet.dart
import 'package:flutter/material.dart';
import 'package:afyakit/tenants/tenant_model.dart';

class EditTenantPayload {
  final String displayName;
  final String primaryColor;
  final String? logoPath;
  final Map<String, dynamic>? flags;
  const EditTenantPayload({
    required this.displayName,
    required this.primaryColor,
    this.logoPath,
    this.flags,
  });
}

class EditTenantSheet extends StatefulWidget {
  const EditTenantSheet({
    super.key,
    required this.tenant,
    required this.onSubmit,
  });
  final Tenant tenant;
  final Future<void> Function(EditTenantPayload payload) onSubmit;

  @override
  State<EditTenantSheet> createState() => _EditTenantSheetState();
}

class _EditTenantSheetState extends State<EditTenantSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _logoCtrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.tenant.displayName);
    _colorCtrl = TextEditingController(text: widget.tenant.primaryColor);
    _logoCtrl = TextEditingController(text: widget.tenant.logoPath ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    _logoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Form(
        key: _formKey,
        child: Wrap(
          runSpacing: 12,
          children: [
            const Text(
              'Edit Tenant',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Display name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _colorCtrl,
              decoration: const InputDecoration(
                labelText: 'Primary color (hex)',
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                final ok = RegExp(r'^#?[0-9A-Fa-f]{6}$').hasMatch(s);
                return ok ? null : 'Use #RRGGBB';
              },
            ),
            TextFormField(
              controller: _logoCtrl,
              decoration: const InputDecoration(
                labelText: 'Logo path (optional)',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save'),
                onPressed: _busy
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _busy = true);
                        try {
                          await widget.onSubmit(
                            EditTenantPayload(
                              displayName: _nameCtrl.text.trim(),
                              primaryColor: _colorCtrl.text.trim(),
                              logoPath: _logoCtrl.text.trim().isEmpty
                                  ? null
                                  : _logoCtrl.text.trim(),
                            ),
                          );
                          if (mounted) Navigator.pop(context, true);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to save: $e')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
