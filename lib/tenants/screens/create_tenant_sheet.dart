import 'package:flutter/material.dart';

class CreateTenantPayload {
  final String displayName;
  final String? slug;
  final String primaryColor;
  final String? logoPath;
  final Map<String, dynamic> flags;

  const CreateTenantPayload({
    required this.displayName,
    this.slug,
    required this.primaryColor,
    this.logoPath,
    this.flags = const {},
  });
}

class CreateTenantSheet extends StatefulWidget {
  const CreateTenantSheet({super.key, required this.onSubmit});
  final Future<void> Function(CreateTenantPayload payload) onSubmit;

  @override
  State<CreateTenantSheet> createState() => _CreateTenantSheetState();
}

class _CreateTenantSheetState extends State<CreateTenantSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _colorCtrl = TextEditingController(text: '#1565C0');
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _colorCtrl.dispose();
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
              'Create Tenant',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Display name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _slugCtrl,
              decoration: const InputDecoration(labelText: 'Slug (optional)'),
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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Create'),
                onPressed: _busy
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _busy = true);
                        try {
                          await widget.onSubmit(
                            CreateTenantPayload(
                              displayName: _nameCtrl.text.trim(),
                              slug: _slugCtrl.text.trim().isEmpty
                                  ? null
                                  : _slugCtrl.text.trim(),
                              primaryColor: _normalizeHex(_colorCtrl.text),
                            ),
                          );
                          if (mounted) Navigator.pop(context, true);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to create tenant: $e'),
                              ),
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

  String _normalizeHex(String input) {
    final s = input.trim().toUpperCase();
    return s.startsWith('#') ? s : '#$s';
  }
}
