// lib/features/records/native_contacts/widgets/native_contacts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/features/records/delivery_addresses/models/delivery_address_scope.dart';
import 'package:afyakit/features/records/delivery_addresses/widgets/delivery_addresses_screen.dart';

import '../native_contacts_controller.dart';
import '../native_contact.dart';
import 'native_contact_tile.dart';
import 'contact_linked_profiles_screen.dart';

/// Staff-facing canonical Native Contacts, independent of Retail accounting.
class NativeContactsScreen extends ConsumerStatefulWidget {
  const NativeContactsScreen({
    super.key,
    this.requireIdForPersons = false,
    this.allowAdminPurge = false,
  });

  /// UI hint only; server enforces the Occuwell identity policy.
  final bool requireIdForPersons;

  /// Deprecated compatibility flag. Lifecycle administration moved to HQ.
  /// Ignored by this staff-facing directory.
  final bool allowAdminPurge;

  @override
  ConsumerState<NativeContactsScreen> createState() =>
      _NativeContactsScreenState();
}

class _NativeContactsScreenState extends ConsumerState<NativeContactsScreen> {
  String _query = '';
  String? _expandedContactId;

  void _toggleContact(String contactId) {
    setState(() {
      _expandedContactId = _expandedContactId == contactId ? null : contactId;
    });
  }

  Future<void> _edit({NativeContact? existing}) async {
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _ContactEditDialog(
        existing: existing,
        requireIdForPersons: widget.requireIdForPersons,
      ),
    );
    if (!mounted || values == null) return;
    final ok = await ref
        .read(nativeContactsControllerProvider.notifier)
        .save(values, accountNumber: existing?.accountNumber);
    if (!mounted) return;
    if (!ok) _showActionError();
  }

  void _showActionError() {
    final error = ref.read(nativeContactsControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Unable to update Contact')),
    );
  }

  Future<void> _openLinkedProfiles(NativeContact contact) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ContactLinkedProfilesScreen(contact: contact),
      ),
    );
  }

  Future<void> _openDeliveryAddresses(NativeContact contact) async {
    final tenantId = ref.read(tenantIdProvider).trim().toLowerCase();
    // Native Contact account number is the canonical contact document ID.
    final contactId = (contact.accountNumber).trim();
    if (tenantId.isEmpty || contactId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot open addresses without a valid native Contact.',
          ),
        ),
      );
      return;
    }
    if (contact.status != 'active') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This Contact is not active.')),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DeliveryAddressesScreen(
          scope: DeliveryAddressScope(
            tenantId: tenantId,
            contactId: contactId,
            ownerLabel: contact.displayName,
          ),
          memberMode: false,
        ),
      ),
    );
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
      if ((contact.accountNumber).trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact account number is missing.')),
        );
        return;
      }
      await ref
          .read(nativeContactsControllerProvider.notifier)
          .removeFromApp((contact.accountNumber).trim());
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
                hintText: 'Filter first page of contacts',
              ),
              onChanged: (text) =>
                  setState(() => _query = text.trim().toLowerCase()),
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
                final filtered =
                    contacts.where((contact) {
                      final searchable = [
                        contact.displayName,
                        contact.companyName ?? '',
                        contact.phone ?? '',
                        contact.mobile ?? '',
                        contact.email ?? '',
                        contact.accountNumber,
                        contact.verifiedPhone ?? '',
                      ].join(' ').toLowerCase();
                      return searchable.contains(_query);
                    }).toList()..sort((a, b) {
                      final byName = a.displayName
                          .trim()
                          .toLowerCase()
                          .compareTo(b.displayName.trim().toLowerCase());
                      if (byName != 0) return byName;
                      return a.accountNumber.compareTo(b.accountNumber);
                    });

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        _query.isEmpty
                            ? '${contacts.length} contacts'
                            : '${filtered.length} of ${contacts.length} contacts',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No contacts found'))
                          : RefreshIndicator(
                              onRefresh: controller.refresh,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final contact = filtered[index];
                                  return NativeContactTile(
                                    key: ValueKey(contact.id),
                                    contact: contact,
                                    expanded: _expandedContactId == contact.id,
                                    busy: actions.busy,
                                    onToggle: () => _toggleContact(contact.id),
                                    onAddresses: () =>
                                        _openDeliveryAddresses(contact),
                                    onProfiles: () =>
                                        _openLinkedProfiles(contact),
                                    onEdit: () {
                                      if (contact.status == 'active') {
                                        _edit(existing: contact);
                                      }
                                    },
                                    onRemove: () => _remove(contact),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Owns and disposes text controllers only after the dialog leaves the tree.
class _ContactEditDialog extends StatefulWidget {
  const _ContactEditDialog({this.existing, required this.requireIdForPersons});
  final NativeContact? existing;
  final bool requireIdForPersons;
  @override
  State<_ContactEditDialog> createState() => _ContactEditDialogState();
}

class _ContactEditDialogState extends State<_ContactEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _email;
  late final TextEditingController _idNumber;
  late String _entityType;
  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.displayName ?? '');
    _mobile = TextEditingController(text: existing?.mobile ?? '');
    _email = TextEditingController(text: existing?.email ?? '');
    _idNumber = TextEditingController(text: existing?.idNumber ?? '');
    _entityType = existing?.entityType ?? 'person';
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    _idNumber.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    // Preserve verified_phone: editing mobile never verifies authentication identity.
    final existing = widget.existing;
    final body = <String, Object?>{
      'display_name': _name.text.trim(),
      if (existing == null) 'entity_type': _entityType,
      if (existing == null) 'contact_type': 'customer',
    };
    for (final pair in [
      ('mobile', _mobile.text),
      ('email', _email.text),
      if (widget.requireIdForPersons) ('id_number', _idNumber.text),
    ]) {
      final value = pair.$2.trim();
      if (existing != null || value.isNotEmpty) {
        body[pair.$1] = value.isEmpty ? null : value;
      }
    }
    Navigator.of(context).pop(body);
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return AlertDialog(
      title: Text(existing == null ? 'New contact' : 'Edit contact'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Display name *',
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Required' : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _entityType,
                  decoration: const InputDecoration(labelText: 'Entity type'),
                  items: const [
                    DropdownMenuItem(value: 'person', child: Text('Person')),
                    DropdownMenuItem(
                      value: 'organization',
                      child: Text('Organisation'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _entityType = value);
                  },
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
                  controller: _mobile,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile *',
                    hintText: '+254712345678',
                    helperText: 'Kenyan mobile number in international format.',
                  ),
                  validator: (value) {
                    final mobile = (value ?? '').trim();
                    if (!RegExp(r'^\+254[17]\d{8}$').hasMatch(mobile)) {
                      return 'Use +254 followed by 9 digits (starting with 7 or 1)';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Account number'),
                  subtitle: Text(
                    (existing?.accountNumber.isNotEmpty ?? false)
                        ? existing!.accountNumber
                        : 'Assigned automatically when saved',
                  ),
                ),
                if (widget.requireIdForPersons)
                  TextFormField(
                    controller: _idNumber,
                    decoration: InputDecoration(
                      labelText:
                          widget.requireIdForPersons && _entityType == 'person'
                          ? 'National ID number *'
                          : 'National ID number (optional)',
                    ),
                    validator: (value) =>
                        widget.requireIdForPersons &&
                            _entityType == 'person' &&
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
