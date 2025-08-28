import 'package:afyakit/hq/core/tenants/models/tenant_payloads.dart';
import 'package:flutter/material.dart';

class AddAdminDialog extends StatefulWidget {
  const AddAdminDialog({super.key, required this.tenantSlug});

  final String tenantSlug; // purely for display; no logic

  @override
  State<AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends State<AddAdminDialog> {
  final _email = TextEditingController();
  bool _forceResend = false;
  bool _busy = false;

  // Role to grant on invite
  String _role = 'admin'; // 'admin' | 'manager'

  @override
  void dispose() {
    _email
      ..removeListener(() {})
      ..dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _toast(context, 'Email is required');
      return;
    }
    if (!email.contains('@')) {
      _toast(context, 'Please enter a valid email.');
      return;
    }
    if (_busy) return;

    setState(() => _busy = true);
    Navigator.pop(
      context,
      AddAdminPayload(email: email, role: _role, forceResend: _forceResend),
    );
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
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              onChanged: (v) => setState(() => _role = (v ?? 'admin')),
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
          onPressed: _busy ? null : () => Navigator.pop(context, null),
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
