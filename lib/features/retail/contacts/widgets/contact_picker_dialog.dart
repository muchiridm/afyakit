import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/records/native_contacts/native_contact.dart';
import 'package:afyakit/features/records/native_contacts/member_native_contact_provider.dart';
import 'package:afyakit/features/records/native_contacts/native_contacts_service.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy_enum.dart';
import 'package:afyakit/features/retail/quotes/providers/quote_contact_policy_provider.dart';

/// Staff picker returning a canonical NativeContact (AC-XXXXXX).
///
/// For member-scoped quotes, no picker or Zoho lookup is needed: the backend
/// determines the authenticated payer. Member mode therefore displays a
/// read-only explanation rather than calling the staff-only contacts GET.
class ContactPickerDialog extends ConsumerStatefulWidget {
  const ContactPickerDialog({super.key, this.forcePickerMode = false});

  final bool forcePickerMode;

  @override
  ConsumerState<ContactPickerDialog> createState() =>
      _ContactPickerDialogState();
}

class _ContactPickerDialogState extends ConsumerState<ContactPickerDialog> {
  static const int _pageSize = 50;

  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  List<NativeContact> _items = <NativeContact>[];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  int _generation = 0;
  String? _error;

  bool get _memberMode =>
      !widget.forcePickerMode &&
      ref.read(quoteContactPolicyProvider) == QuoteContactPolicy.memberScoped;

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        if (mounted) setState(() {});
      });
    });
    _scroll.addListener(() {
      if (_memberMode || _loading || !_hasMore || !_scroll.hasClients) return;
      if (_scroll.position.extentAfter < 200) {
        unawaited(_load(_page + 1));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_memberMode) unawaited(_load(1));
    });
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load(int page) async {
    if (!mounted || _memberMode || _loading) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = await ref.read(nativeContactsServiceProvider.future);
      final contacts = await service.list(page: page, perPage: _pageSize);
      if (!mounted || generation != _generation) return;
      setState(() {
        _page = page;
        _hasMore = contacts.length == _pageSize;
        _items = page == 1 ? contacts : <NativeContact>[..._items, ...contacts];
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberMode =
        !widget.forcePickerMode &&
        ref.watch(quoteContactPolicyProvider) ==
            QuoteContactPolicy.memberScoped;
    final accountNumber = ref.watch(currentMemberAccountNumberProvider);
    final query = _search.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? _items
        : _items
              .where(
                (contact) =>
                    contact.displayName.toLowerCase().contains(query) ||
                    contact.id.toLowerCase().contains(query) ||
                    (contact.accountNumber).toLowerCase().contains(query) ||
                    (contact.phone ?? '').toLowerCase().contains(query) ||
                    (contact.email ?? '').toLowerCase().contains(query),
              )
              .toList();

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
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Filter loaded contacts',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Search filters loaded pages only.',
                    style: TextStyle(fontSize: 11),
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final contact = visible[index];
                        return ListTile(
                          title: Text(contact.displayName),
                          subtitle: Text(contact.accountNumber),
                          onTap: () =>
                              Navigator.of(context).pop<NativeContact>(contact),
                        );
                      },
                    ),
                  ),
                  if (_loading) const LinearProgressIndicator(),
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
