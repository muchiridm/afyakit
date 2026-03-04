import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/widgets/app_empty_state.dart';
import 'package:afyakit/shared/widgets/app_search_field.dart';

import '../../shared/models/zoho_contact.dart';
import '../services/zoho_contacts_service.dart';

class ContactPickerDialog extends ConsumerStatefulWidget {
  const ContactPickerDialog({super.key});

  @override
  ConsumerState<ContactPickerDialog> createState() =>
      _ContactPickerDialogState();
}

class _ContactPickerDialogState extends ConsumerState<ContactPickerDialog> {
  final _ctl = TextEditingController();
  Timer? _debounce;

  bool _loading = false;
  String? _error;
  List<ZohoContact> _items = const <ZohoContact>[];

  @override
  void initState() {
    super.initState();

    // Initial load (no search)
    _load();

    _ctl.addListener(_scheduleLoad);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.removeListener(_scheduleLoad);
    _ctl.dispose();
    super.dispose();
  }

  void _scheduleLoad() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _load);
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final svc = await ref.read(zohoContactsServiceProvider.future);
      final q = _ctl.text.trim();
      final items = await svc.list(search: q.isEmpty ? null : q);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _items = const <ZohoContact>[];
      });
    }
  }

  void _clearAndReload() {
    // Avoid double-triggering from controller listener
    _debounce?.cancel();
    _ctl.clear();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final q = _ctl.text.trim();
    final hasQuery = q.isNotEmpty;

    Widget body;

    if (_loading && _items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = _ErrorState(message: _error!, onRetry: _load);
    } else if (_items.isEmpty) {
      body = AppEmptyState(
        icon: Icons.people_alt_outlined,
        title: hasQuery ? 'No results' : 'Search contacts',
        subtitle: hasQuery
            ? 'Try a different search.'
            : 'Type a name, phone, or email to find a customer.',
        actionLabel: hasQuery ? 'Clear search' : 'Refresh',
        onAction: () {
          if (hasQuery) {
            _clearAndReload();
          } else {
            _load();
          }
        },
      );
    } else {
      body = ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final c = _items[i];

          final subtitle =
              <String?>[c.personContact?.personName, c.companyName, c.bestPhone]
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
      );
    }

    return AlertDialog(
      title: const Text('Pick contact'),
      content: SizedBox(
        width: 520,
        child: LayoutBuilder(
          builder: (context, c) {
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: c.maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppSearchField(
                    controller: _ctl,
                    hintText: 'Search contacts…',
                    loading: _loading,
                    onClear: _clearAndReload,
                  ),
                  const SizedBox(height: 12),
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
