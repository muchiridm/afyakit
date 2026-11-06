import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/records/native_contacts/native_contact.dart';
import 'package:afyakit/features/records/native_contacts/native_contacts_controller.dart';
import 'package:afyakit/features/records/native_contacts/member_native_contact_provider.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy_enum.dart';
import 'package:afyakit/features/retail/quotes/providers/quote_contact_policy_provider.dart';

/// Staff picker returning a canonical NativeContact (AC-XXXXXX or ORG-XXXXXX).
/// Uses the same first-page Riverpod cache as NativeContactsScreen.
/// Member-scoped quotes never load the staff contacts directory.
class ContactPickerDialog extends ConsumerStatefulWidget {
  const ContactPickerDialog({super.key, this.forcePickerMode = false});

  final bool forcePickerMode;

  @override
  ConsumerState<ContactPickerDialog> createState() =>
      _ContactPickerDialogState();
}

class _ContactPickerDialogState extends ConsumerState<ContactPickerDialog> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<NativeContact> _filterContacts(List<NativeContact> contacts) {
    final query = _query;
    final filtered = contacts.where((contact) {
      if (query.isEmpty) return true;

      final searchable = <String>[
        contact.displayName,
        contact.accountNumber,
        contact.phone ?? '',
        contact.email ?? '',
        contact.verifiedPhone ?? '',
        contact.verifiedEmail ?? '',
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();

    filtered.sort((a, b) {
      final byName = a.displayName.trim().toLowerCase().compareTo(
        b.displayName.trim().toLowerCase(),
      );
      return byName != 0 ? byName : a.accountNumber.compareTo(b.accountNumber);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final memberMode =
        !widget.forcePickerMode &&
        ref.watch(quoteContactPolicyProvider) ==
            QuoteContactPolicy.memberScoped;

    // Do not subscribe to the staff-only directory in member mode.
    final contactsAsync = memberMode
        ? null
        : ref.watch(nativeContactsListProvider);
    final accountNumber = memberMode
        ? ref.watch(currentMemberAccountNumberProvider)
        : null;

    return AlertDialog(
      title: Text(
        memberMode ? 'Your customer account' : 'Select Native Contact',
      ),
      content: SizedBox(
        width: 520,
        height: memberMode ? 150 : 460,
        child: memberMode
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    accountNumber == null
                        ? 'No Native Contact account is linked to this session.'
                        : 'Account: $accountNumber',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your customer identity is verified by the backend when you request a quote. You do not need to choose a Zoho customer.',
                  ),
                ],
              )
            : Column(
                children: <Widget>[
                  TextField(
                    controller: _search,
                    onChanged: (value) {
                      setState(() => _query = value.trim().toLowerCase());
                    },
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText:
                          'Filter contacts by name, account, phone or email',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: contactsAsync!.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text('Unable to load contacts: $error'),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () =>
                                  ref.invalidate(nativeContactsListProvider),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      data: (contacts) {
                        final visible = _filterContacts(contacts);
                        if (visible.isEmpty) {
                          return const Center(child: Text('No contacts found'));
                        }
                        return ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final contact = visible[index];
                            return ListTile(
                              key: ValueKey(contact.accountNumber),
                              title: Text(contact.displayName),
                              subtitle: Text(contact.accountNumber),
                              onTap: () => Navigator.of(
                                context,
                              ).pop<NativeContact>(contact),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (contactsAsync.hasValue)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Showing ${_filterContacts(contactsAsync.value!).length} '
                        'of ${contactsAsync.value!.length} loaded contacts. '
                        'Search filters the loaded first page only.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
