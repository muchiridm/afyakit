// lib/features/retail/quotes/widgets/contact_picker_dialog.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contacts/models/zoho_contact.dart';
import '../../contacts/services/zoho_contacts_service.dart';

class ContactPickerDialog extends StatefulWidget {
  const ContactPickerDialog({super.key, required this.ref});
  final Ref ref;

  @override
  State<ContactPickerDialog> createState() => _ContactPickerDialogState();
}

class _ContactPickerDialogState extends State<ContactPickerDialog> {
  final _ctl = TextEditingController();
  Timer? _debounce;

  bool _loading = false;
  String? _error;
  List<ZohoContact> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();

    _ctl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), _load);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final svc = await widget.ref.read(zohoContactsServiceProvider.future);
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
                  TextField(
                    controller: _ctl,
                    decoration: InputDecoration(
                      hintText: 'Search contacts…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : (_ctl.text.trim().isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _ctl.clear();
                                      _load();
                                    },
                                  )),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  Flexible(
                    child: _loading && _items.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final c = _items[i];

                              final subtitle =
                                  <String?>[
                                        c.personContact?.personName,
                                        c.companyName,
                                        c.bestPhone,
                                      ]
                                      .whereType<String>()
                                      .map((s) => s.trim())
                                      .where((s) => s.isNotEmpty)
                                      .take(2)
                                      .join(' • ');

                              return ListTile(
                                title: Text(c.displayName),
                                subtitle: subtitle.trim().isEmpty
                                    ? null
                                    : Text(subtitle),
                                onTap: () => Navigator.of(context).pop(c),
                              );
                            },
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
