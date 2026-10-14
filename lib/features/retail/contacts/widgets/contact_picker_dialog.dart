import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/records/native_contacts/models/native_contact.dart';
import 'package:afyakit/features/records/native_contacts/services/native_contacts_service.dart';
import 'package:afyakit/features/retail/contacts/providers/zoho_contacts_providers.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy_enum.dart';
import 'package:afyakit/features/retail/quotes/providers/quote_contact_policy_provider.dart';

/// Returns a NativeContact. Callers must resolve an app-scoped Zoho mapping
/// separately before writing any Zoho invoice or quote.
class ContactPickerDialog extends ConsumerStatefulWidget {
  const ContactPickerDialog({super.key, this.forcePickerMode = false});
  final bool forcePickerMode;
  @override
  ConsumerState<ContactPickerDialog> createState() =>
      _ContactPickerDialogState();
}

class _ContactPickerDialogState extends ConsumerState<ContactPickerDialog> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  List<NativeContact> _items = [];
  bool _loading = false, _hasMore = true;
  int _page = 1, _seq = 0;
  String? _error;
  String? _memberId;

  bool get _memberMode =>
      !widget.forcePickerMode &&
      ref.read(quoteContactPolicyProvider) == QuoteContactPolicy.memberScoped;

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), _refresh);
    });
    _scroll.addListener(() {
      if (_memberMode || _loading || !_hasMore || !_scroll.hasClients) return;
      if (_scroll.position.extentAfter < 200) _load(_page + 1);
    });
    Future.microtask(_refresh);
  }

  @override
  void dispose() {
    _seq++;
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _load(1);

  Future<void> _load(int page) async {
    if (!mounted || _loading) return;
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = await ref.read(nativeContactsServiceProvider.future);
      if (_memberMode) {
        final id = ref.read(currentMemberNativeContactIdProvider)?.trim() ?? '';
        _memberId = id;
        if (id.isEmpty) {
          throw StateError('No Native Contact linked to this member');
        }
        final c = await svc.get(id);
        if (!mounted || seq != _seq) return;
        Navigator.of(context).pop<NativeContact>(c);
        return;
      }
      final pageItems = await svc.list(page: page, perPage: 50);
      if (!mounted || seq != _seq) return;
      setState(() {
        _page = page;
        _hasMore = pageItems.length == 50;
        _items = page == 1 ? pageItems : [..._items, ...pageItems];
      });
    } catch (error) {
      if (mounted && seq == _seq) setState(() => _error = '$error');
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final member =
        !widget.forcePickerMode &&
        ref.watch(quoteContactPolicyProvider) ==
            QuoteContactPolicy.memberScoped;
    final q = _search.text.trim().toLowerCase();
    final visible = q.isEmpty
        ? _items
        : _items
              .where(
                (c) =>
                    c.displayName.toLowerCase().contains(q) ||
                    c.id.toLowerCase().contains(q) ||
                    (c.phone ?? '').toLowerCase().contains(q) ||
                    (c.email ?? '').toLowerCase().contains(q),
              )
              .toList();
    return AlertDialog(
      title: Text(member ? 'Your contact' : 'Select Native Contact'),
      content: SizedBox(
        width: 520,
        height: 460,
        child: Column(
          children: [
            if (!member) ...[
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Filter loaded contacts',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Search filters loaded pages only; global search needs a backend endpoint.',
                style: TextStyle(fontSize: 11),
              ),
            ],
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_memberId != null && member) Text('Contact: $_memberId'),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                itemCount: visible.length,
                itemBuilder: (context, i) {
                  final c = visible[i];
                  return ListTile(
                    title: Text(c.displayName),
                    subtitle: Text(c.accountNumber ?? c.id),
                    onTap: () => Navigator.of(context).pop<NativeContact>(c),
                  );
                },
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
