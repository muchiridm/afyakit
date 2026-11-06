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
                        contact.legacyDisplayName ?? '',
                        contact.phone ?? '',
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

                final missingNames = contacts.where((contact) {
                  if (contact.isOrganization) {
                    return (contact.companyName ?? '').trim().isEmpty;
                  }
                  return (contact.firstName ?? '').trim().isEmpty ||
                      (contact.lastName ?? '').trim().isEmpty;
                }).length;

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
                            ? '${contacts.length} contacts${missingNames > 0 ? ' · $missingNames missing names' : ''}'
                            : '${filtered.length} of ${contacts.length} contacts${missingNames > 0 ? ' · $missingNames missing names' : ''}',
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

/// Staff editor for canonical Native Contacts.
/// Person names are stored separately; display_name is derived by the backend.
class _ContactEditDialog extends StatefulWidget {
  const _ContactEditDialog({this.existing, required this.requireIdForPersons});

  final NativeContact? existing;
  final bool requireIdForPersons;

  @override
  State<_ContactEditDialog> createState() => _ContactEditDialogState();
}

class _ContactEditDialogState extends State<_ContactEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _companyName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _idNumber;
  late String _entityType;

  /// Normalise recognised Kenyan mobile formats without changing the verified
  /// authentication identity. Other input is left for validation to reject.
  static String _normaliseKenyanMobile(String input) {
    final value = input.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (RegExp(r'^0[17]\d{8}$').hasMatch(value)) {
      return '+254${value.substring(1)}';
    }
    if (RegExp(r'^254[17]\d{8}$').hasMatch(value)) {
      return '+$value';
    }
    if (RegExp(r'^[17]\d{8}$').hasMatch(value)) {
      return '+254$value';
    }
    return value;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _entityType = existing?.entityType ?? 'person';
    _firstName = TextEditingController(text: existing?.firstName ?? '');
    _lastName = TextEditingController(text: existing?.lastName ?? '');
    _companyName = TextEditingController(text: existing?.companyName ?? '');
    _phone = TextEditingController(
      text: _normaliseKenyanMobile(existing?.phone ?? ''),
    );
    _email = TextEditingController(text: existing?.email ?? '');
    _idNumber = TextEditingController(text: existing?.idNumber ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _companyName.dispose();
    _phone.dispose();
    _email.dispose();
    _idNumber.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final existing = widget.existing;
    final normalisedPhone = _normaliseKenyanMobile(_phone.text);
    final body = <String, Object?>{
      if (existing == null) 'entity_type': _entityType,
      if (existing == null) 'contact_type': 'customer',
    };

    if (_entityType == 'person') {
      // Never manufacture a surname or send the derived display_name.
      body['first_name'] = _firstName.text.trim();
      body['last_name'] = _lastName.text.trim();
    } else {
      body['company_name'] = _companyName.text.trim();
    }

    // The backend stores phone, not mobile. Verified identity fields are
    // read-only and are never sent by this editor.
    for (final pair in [
      ('phone', normalisedPhone),
      ('email', _email.text),
      if (widget.requireIdForPersons && _entityType == 'person')
        ('id_number', _idNumber.text),
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
    final isPerson = _entityType == 'person';

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
                  // Backend does not permit changing an entity's type.
                  onChanged: existing == null
                      ? (value) {
                          if (value != null) {
                            setState(() => _entityType = value);
                          }
                        }
                      : null,
                ),
                if (isPerson) ...[
                  if (existing != null &&
                      ((existing.firstName ?? '').trim().isEmpty ||
                          (existing.lastName ?? '').trim().isEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        (existing.legacyDisplayName ?? '').isNotEmpty
                            ? 'Previous display name: ${existing.legacyDisplayName}. '
                              'Confirm the correct first and last names separately.'
                            : 'This contact is missing a first or last name. '
                              'Enter both names as recorded; do not guess.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  TextFormField(
                    controller: _firstName,
                    decoration: const InputDecoration(
                      labelText: 'First name *',
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'First name is required'
                        : null,
                  ),
                  TextFormField(
                    controller: _lastName,
                    decoration: const InputDecoration(labelText: 'Last name *'),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Last name is required'
                        : null,
                  ),
                ] else
                  TextFormField(
                    controller: _companyName,
                    decoration: const InputDecoration(
                      labelText: 'Company name *',
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Company name is required'
                        : null,
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
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone *',
                    hintText: '+254712345678',
                    helperText: 'Kenyan mobile number in international format.',
                  ),
                  validator: (value) {
                    final phone = _normaliseKenyanMobile(value ?? '');
                    if (!RegExp(r'^\+254[17]\d{8}$').hasMatch(phone)) {
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
                  validator: (value) {
                    final email = (value ?? '').trim();
                    if (email.isNotEmpty &&
                        !RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(email)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
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
                if (widget.requireIdForPersons && isPerson)
                  TextFormField(
                    controller: _idNumber,
                    decoration: const InputDecoration(
                      labelText: 'National ID number *',
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
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
