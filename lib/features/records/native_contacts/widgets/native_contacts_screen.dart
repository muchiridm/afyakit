import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/native_contacts_controller.dart';
import '../models/native_contact.dart';

/// Staff-facing native Contacts, independent of Retail and Zoho Books.
class NativeContactsScreen extends ConsumerStatefulWidget {
  const NativeContactsScreen({super.key, this.requireIdForPersons = false});

  /// UI hint only; server enforces the Occuwell identity policy.
  final bool requireIdForPersons;

  @override
  ConsumerState<NativeContactsScreen> createState() =>
      _NativeContactsScreenState();
}

class _NativeContactsScreenState extends ConsumerState<NativeContactsScreen> {
  String query = '';

  Future<void> _edit({NativeContact? existing}) async {
    // Fetch a fresh record before editing (list may omit fields in future).
    final name = TextEditingController(text: existing?.displayName ?? '');
    final company = TextEditingController(text: existing?.companyName ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final mobile = TextEditingController(text: existing?.mobile ?? '');
    final email = TextEditingController(text: existing?.email ?? '');
    final idNumber = TextEditingController(text: existing?.idNumber ?? '');
    var entityType = existing?.entityType ?? 'person';
    var contactType = existing?.contactType ?? 'customer';
    final formKey = GlobalKey<FormState>();
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, redraw) => AlertDialog(
          title: Text(existing == null ? 'New contact' : 'Edit contact'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Display name *',
                      ),
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'Required' : null,
                    ),
                    DropdownButtonFormField<String>(
                      value: entityType,
                      decoration: const InputDecoration(
                        labelText: 'Entity type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'person',
                          child: Text('Person'),
                        ),
                        DropdownMenuItem(
                          value: 'organization',
                          child: Text('Organisation'),
                        ),
                      ],
                      onChanged: (value) =>
                          redraw(() => entityType = value ?? entityType),
                    ),
                    DropdownButtonFormField<String>(
                      value: contactType,
                      decoration: const InputDecoration(
                        labelText: 'Contact type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'customer',
                          child: Text('Customer'),
                        ),
                        DropdownMenuItem(
                          value: 'vendor',
                          child: Text('Vendor'),
                        ),
                        DropdownMenuItem(
                          value: 'customer_vendor',
                          child: Text('Customer and vendor'),
                        ),
                      ],
                      onChanged: (value) =>
                          redraw(() => contactType = value ?? contactType),
                    ),
                    TextFormField(
                      controller: company,
                      decoration: const InputDecoration(labelText: 'Company'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.verified_user_outlined),
                      title: const Text('Verified account phone'),
                      subtitle: Text(
                        (existing?.verifiedPhone?.isNotEmpty ?? false)
                            ? existing!.verifiedPhone!
                            : 'Not verified or not linked to an account',
                      ),
                    ),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    TextFormField(
                      controller: mobile,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Mobile'),
                    ),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Account number'),
                      subtitle: Text(
                        (existing?.accountNumber?.isNotEmpty ?? false)
                            ? existing!.accountNumber!
                            : 'Not assigned — generate from contact actions',
                      ),
                    ),
                    TextFormField(
                      controller: idNumber,
                      decoration: InputDecoration(
                        labelText:
                            widget.requireIdForPersons && entityType == 'person'
                            ? 'National ID number *'
                            : 'National ID number (optional)',
                      ),
                      validator: (value) =>
                          widget.requireIdForPersons &&
                              entityType == 'person' &&
                              (value ?? '').trim().isEmpty
                          ? 'Required for Occuwell'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final body = <String, Object?>{
                  'display_name': name.text.trim(),
                  'entity_type': entityType,
                  'contact_type': contactType,
                };
                for (final pair in [
                  ('company_name', company.text),
                  ('phone', phone.text),
                  ('mobile', mobile.text),
                  ('email', email.text),
                  ('id_number', idNumber.text),
                ]) {
                  final value = pair.$2.trim();
                  if (existing != null || value.isNotEmpty) {
                    body[pair.$1] = value.isEmpty ? null : value;
                  }
                }
                Navigator.pop(dialogContext, body);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    // Release controllers after the dialog has been dismissed.
    name.dispose();
    company.dispose();
    phone.dispose();
    mobile.dispose();
    email.dispose();
    idNumber.dispose();
    if (values == null || !mounted) return;
    await ref
        .read(nativeContactsControllerProvider.notifier)
        .save(values, contactId: existing?.id);
  }

  Future<void> _remove(NativeContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from this app?'),
        content: Text(
          'Remove ${contact.displayName} from this application? '
          'The shared contact will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref
          .read(nativeContactsControllerProvider.notifier)
          .removeFromApp(contact.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(nativeContactsListProvider);
    final actions = ref.watch(nativeContactsControllerProvider);
    final controller = ref.read(nativeContactsControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: actions.busy ? null : controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Add contact',
            onPressed: actions.busy ? null : () => _edit(),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Filter loaded contacts',
              ),
              onChanged: (text) =>
                  setState(() => query = text.trim().toLowerCase()),
            ),
          ),
          if (actions.busy) const LinearProgressIndicator(),
          if (actions.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                actions.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: list.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Unable to load contacts: $error')),
              data: (contacts) {
                final filtered = contacts
                    .where(
                      (c) =>
                          '${c.displayName} ${c.companyName ?? ''} ${c.phone ?? ''} '
                                  '${c.email ?? ''} ${c.accountNumber ?? ''} ${c.verifiedPhone ?? ''}'
                              .toLowerCase()
                              .contains(query),
                    )
                    .toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No contacts found'));
                }
                return RefreshIndicator(
                  onRefresh: controller.refresh,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final contact = filtered[index];
                      return ListTile(
                        leading: Icon(
                          contact.entityType == 'organization'
                              ? Icons.business
                              : Icons.person_outline,
                        ),
                        title: Text(contact.displayName),
                        subtitle: Text(
                          [
                                contact.accountNumber,
                                if (contact.verifiedPhone?.isNotEmpty ?? false)
                                  'Verified: ${contact.verifiedPhone}',
                                contact.phone,
                                contact.email,
                              ]
                              .where(
                                (value) => value != null && value.isNotEmpty,
                              )
                              .join(' · '),
                        ),
                        onTap: actions.busy
                            ? null
                            : () => _edit(existing: contact),
                        trailing: PopupMenuButton<String>(
                          enabled: !actions.busy,
                          onSelected: (action) async {
                            switch (action) {
                              case 'edit':
                                await _edit(existing: contact);
                              case 'allocate':
                                await ref
                                    .read(
                                      nativeContactsControllerProvider.notifier,
                                    )
                                    .generateAccountNumber(contact.id);
                              case 'remove':
                                await _remove(contact);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            if (contact.accountNumber == null ||
                                contact.accountNumber!.isEmpty)
                              const PopupMenuItem(
                                value: 'allocate',
                                child: Text('Generate account number'),
                              ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove from this app'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
