import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/tenants/tenant_controller.dart';

class AddAdminDialog extends ConsumerStatefulWidget {
  const AddAdminDialog({super.key, required this.tenantSlug});

  final String tenantSlug;

  @override
  ConsumerState<AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends ConsumerState<AddAdminDialog> {
  final _email = TextEditingController();
  bool _forceResend = false;
  bool _busy = false;

  // NEW: pick role on invite (defaults to admin)
  String _role = 'admin'; // 'admin' | 'manager'

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _toast(context, 'Email is required');
      return;
    }

    setState(() => _busy = true);
    try {
      final controller = ref.read(tenantControllerProvider);
      await controller.inviteAdminByEmail(
        context,
        slug: widget.tenantSlug,
        email: email,
        role: _role, // ← assign role in the invite
        forceResend: _forceResend,
      );
      if (!mounted) return;
      Navigator.pop(context, true); // success
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite Tenant Admin'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email *',
                hintText: 'admin@example.com',
              ),
              onSubmitted: (_) => _busy ? null : _submit(),
            ),
            const SizedBox(height: 12),

            // NEW: Role selector
            DropdownButtonFormField<String>(
              initialValue: _role,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _role = v ?? 'admin'),
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'manager', child: Text('Manager')),
              ],
              decoration: const InputDecoration(labelText: 'Role'),
            ),

            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _forceResend,
              onChanged: (v) => setState(() => _forceResend = v ?? false),
              title: const Text('Resend if already invited'),
            ),
            const SizedBox(height: 8),
            const Text(
              'We’ll send an invite to this email. Once they sign in, they’ll appear in Users with the selected role.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Invite'),
        ),
      ],
    );
  }

  void _toast(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
