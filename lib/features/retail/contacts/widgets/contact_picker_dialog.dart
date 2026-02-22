// lib/features/retail/contacts/widgets/contact_picker_dialog.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/widgets/app_empty_state.dart';
import 'package:afyakit/shared/widgets/app_search_field.dart';

import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/home/providers/entry_mode_providers.dart';

import 'package:afyakit/features/retail/contacts/providers/zoho_contact_scope_providers.dart';
import '../services/zoho_contacts_service.dart';
import '../../shared/models/zoho_contact.dart';

class ContactPickerDialog extends ConsumerStatefulWidget {
  const ContactPickerDialog({super.key});

  @override
  ConsumerState<ContactPickerDialog> createState() =>
      _ContactPickerDialogState();
}

class _ContactPickerDialogState extends ConsumerState<ContactPickerDialog> {
  static const int _perPage = 50;
  static const Duration _debounceMs = Duration(milliseconds: 250);

  final _ctl = TextEditingController();
  final _scroll = ScrollController();

  Timer? _debounce;

  bool _loading = false; // initial / refresh load
  bool _loadingMore = false; // pagination load
  String? _error;

  List<ZohoContact> _items = const <ZohoContact>[];

  int _page = 1;
  bool _hasMore = true;

  bool _autoPicked = false; // prevent double-pop in member UX

  @override
  void initState() {
    super.initState();

    _ctl.addListener(_scheduleSearch);
    _scroll.addListener(_maybeLoadMore);

    // initial load
    _refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.removeListener(_scheduleSearch);
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    _ctl.dispose();
    super.dispose();
  }

  EntryMode get _mode => ref.read(effectiveEntryModeProvider);

  bool get _memberUx => _mode == EntryMode.member;

  /// IMPORTANT:
  /// - Member UX: bind to accountNumber (deterministic single customer contact)
  /// - Staff UX: DO NOT apply accountNumber scope (list all contacts)
  String? get _accountNumberScopeIfMember {
    if (!_memberUx) return null;
    final acct = ref.read(zohoContactsAccountScopeProvider);
    final a = (acct ?? '').trim();
    return a.isEmpty ? null : a;
  }

  void _scheduleSearch() {
    // Member UX: search is irrelevant; do not reload on typing.
    if (_memberUx) return;

    _debounce?.cancel();
    _debounce = Timer(_debounceMs, _refresh);
  }

  void _maybeLoadMore() {
    if (_memberUx) return; // member should never paginate
    if (!_hasMore) return;
    if (_loading || _loadingMore) return;
    if (!_scroll.hasClients) return;

    // load when we're close to the bottom
    final pos = _scroll.position;
    if (pos.pixels >= (pos.maxScrollExtent - 240)) {
      _loadMore();
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _items = const <ZohoContact>[];
      _page = 1;
      _hasMore = true;
      _autoPicked = false; // reset for new open/search
    });

    await _loadPage(page: 1, append: false);

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (!mounted) return;
    if (!_hasMore) return;

    setState(() {
      _loadingMore = true;
      _error = null;
    });

    final nextPage = _page + 1;
    await _loadPage(page: nextPage, append: true);

    if (!mounted) return;
    setState(() => _loadingMore = false);
  }

  Future<void> _loadPage({required int page, required bool append}) async {
    try {
      final svc = await ref.read(zohoContactsServiceProvider.future);

      final acct = _accountNumberScopeIfMember;

      // Member UX: ignore search.
      // Staff UX: apply search query if present.
      final q = _memberUx ? '' : _ctl.text.trim();

      final items = await svc.list(
        search: q.isEmpty ? null : q,
        accountNumber: acct, // ✅ NULL in staff mode → list all
        page: page,
        perPage: _perPage,
      );

      if (!mounted) return;

      // basic pagination heuristic:
      // if Zoho returns fewer than perPage, we've reached the end.
      final hasMore = items.length >= _perPage;

      setState(() {
        _page = page;
        _hasMore = hasMore;
        _items = append ? [..._items, ...items] : items;
      });

      // ✅ Member UX: auto-pick deterministically on any match.
      if (_memberUx && !_autoPicked && _items.isNotEmpty) {
        _autoPicked = true;

        // Let the dialog paint at least once before closing.
        Future.microtask(() {
          if (!mounted) return;
          Navigator.of(context).pop(_items.first);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _hasMore = false;
      });
    }
  }

  void _clearAndReload() {
    if (_memberUx) return;
    _debounce?.cancel();
    _ctl.clear();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // reactive for labels, but actual behavior remains driven by the getters above
    final isMemberUx =
        ref.watch(effectiveEntryModeProvider) == EntryMode.member;
    final acct = ref.watch(zohoContactsAccountScopeProvider);

    final q = _ctl.text.trim();
    final hasQuery = q.isNotEmpty;

    Widget body;

    if (_loading && _items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _items.isEmpty) {
      body = _ErrorState(message: _error!, onRetry: _refresh);
    } else if (_items.isEmpty) {
      body = AppEmptyState(
        icon: Icons.people_alt_outlined,
        title: isMemberUx
            ? 'No linked Zoho contact'
            : (hasQuery ? 'No results' : 'Search contacts'),
        subtitle: isMemberUx
            ? 'Your account (${(acct ?? '-').trim().isEmpty ? '-' : (acct ?? '-')}) has no Zoho contact linked yet.'
            : (hasQuery
                  ? 'Try a different search.'
                  : 'Type a name, phone, or email to find a customer.'),
        actionLabel: isMemberUx
            ? 'Retry'
            : (hasQuery ? 'Clear search' : 'Refresh'),
        onAction: () {
          if (isMemberUx) {
            _refresh();
          } else if (hasQuery) {
            _clearAndReload();
          } else {
            _refresh();
          }
        },
      );
    } else {
      body = Stack(
        children: [
          ListView.separated(
            controller: _scroll,
            itemCount: _items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = _items[i];

              final subtitle =
                  <String?>[c.accountNumber, c.contactType, c.bestPhone]
                      .whereType<String>()
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .take(2)
                      .join(' • ');

              final title = c.displayName.trim();

              return ListTile(
                title: Text(title.isEmpty ? 'Contact' : title),
                subtitle: subtitle.trim().isEmpty ? null : Text(subtitle),
                onTap: () => Navigator.of(context).pop(c),
              );
            },
          ),

          if (_loadingMore)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return AlertDialog(
      title: Text(isMemberUx ? 'Your account' : 'Pick contact'),
      content: SizedBox(
        width: 520,
        child: LayoutBuilder(
          builder: (context, c) {
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: c.maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMemberUx) ...[
                    AppSearchField(
                      controller: _ctl,
                      hintText: 'Search contacts…',
                      loading: _loading,
                      onClear: _clearAndReload,
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Account: ${(acct ?? '-').trim().isEmpty ? '-' : (acct ?? '-')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: body,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 40, color: scheme.error),
              const SizedBox(height: 12),
              Text(
                'Couldn’t load contacts',
                style: t.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: t.bodySmall?.copyWith(color: scheme.error),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
