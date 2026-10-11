import 'package:flutter/material.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

/// Read-only, member-scoped account summary.
///
/// Intentionally does NOT call the staff-only native Contacts endpoint.
/// A future /contacts/me endpoint can provide verified phone and ID number
/// after checking the current user's identity and disclosure permissions.
class MemberContactScreen extends StatelessWidget {
  const MemberContactScreen({super.key, required this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final current = user;
    final name = (current?.computedDisplayName ?? '').trim();
    final accountNumber = (current?.accountNumber ?? '').trim();
    final contactId = (current?.contactId ?? '').trim();

    return Scaffold(
      appBar: AppBar(title: const Text('My Contact')),
      body: current == null
          ? const Center(child: Text('Your account is still loading.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My account identity',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _Detail(label: 'Name', value: name),
                        _Detail(label: 'Account number', value: accountNumber),
                        _Detail(
                          label: 'Contact link',
                          value: contactId.isEmpty ? 'Not yet linked' : 'Linked',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const ListTile(
                  leading: Icon(Icons.verified_user_outlined),
                  title: Text('Verified phone and identification'),
                  subtitle: Text(
                    'These details will appear here once a member-authorised '
                    'identity endpoint is connected. They cannot be edited '
                    'through the Contacts directory.',
                  ),
                ),
              ],
            ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 3),
            Text(value.isEmpty ? 'Not available' : value),
          ],
        ),
      );
}
