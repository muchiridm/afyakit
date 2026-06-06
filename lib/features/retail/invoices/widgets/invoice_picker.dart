// lib/features/retail/sales/invoices/widgets/invoice_picker.dart

import 'package:afyakit/features/retail/invoices/zoho_invoice.dart';
import 'package:afyakit/features/retail/invoices/zoho_invoices_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InvoicePickerCard extends ConsumerStatefulWidget {
  const InvoicePickerCard({
    super.key,
    this.initialInvoiceId,
    required this.patientId,
    this.patientNo,
    this.accountNumber,
    this.title = 'Invoice',
    this.emptyText,
    this.onSelected,
  });

  final String? initialInvoiceId;

  /// Required scope. We use this as fallback search if patientNo/accountNumber
  /// is unavailable.
  final String patientId;

  /// Preferred patient-scoped key if your Zoho invoices use patient number /
  /// account number as the reference/account number.
  final String? patientNo;

  /// Optional explicit override.
  final String? accountNumber;

  final String title;
  final String? emptyText;
  final ValueChanged<ZohoInvoice>? onSelected;

  @override
  ConsumerState<InvoicePickerCard> createState() => _InvoicePickerCardState();
}

class _InvoicePickerCardState extends ConsumerState<InvoicePickerCard> {
  final TextEditingController _searchCtl = TextEditingController();

  List<ZohoInvoice> _items = const <ZohoInvoice>[];
  String? _selectedInvoiceId;
  bool _loading = false;
  String? _error;

  String get _scopePatientId => widget.patientId.trim();

  String? get _scopeAccountNumber {
    final String explicit = (widget.accountNumber ?? '').trim();
    if (explicit.isNotEmpty) return explicit;

    final String patientNo = (widget.patientNo ?? '').trim();
    if (patientNo.isNotEmpty) return patientNo;

    return null;
  }

  @override
  void initState() {
    super.initState();

    _selectedInvoiceId = _cleanOrNull(widget.initialInvoiceId);

    Future<void>.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant InvoicePickerCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool scopeChanged =
        oldWidget.patientId.trim() != widget.patientId.trim() ||
        (oldWidget.patientNo ?? '').trim() != (widget.patientNo ?? '').trim() ||
        (oldWidget.accountNumber ?? '').trim() !=
            (widget.accountNumber ?? '').trim();

    final String? nextInitialId = _cleanOrNull(widget.initialInvoiceId);

    if (nextInitialId != _cleanOrNull(oldWidget.initialInvoiceId)) {
      _selectedInvoiceId = nextInitialId;
    }

    if (scopeChanged) {
      _items = const <ZohoInvoice>[];
      _selectedInvoiceId = nextInitialId;
      Future<void>.microtask(_load);
    }
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_scopePatientId.isEmpty && (_scopeAccountNumber ?? '').isEmpty) {
      setState(() {
        _items = const <ZohoInvoice>[];
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ZohoInvoicesService svc = await ref.read(
        zohoInvoicesServiceProvider.future,
      );

      final String search = _searchCtl.text.trim();

      final List<ZohoInvoice> items = await svc.list(
        limit: 100,
        page: 1,
        accountNumber: _scopeAccountNumber,
        q: search.isNotEmpty
            ? search
            : (_scopeAccountNumber == null ? _scopePatientId : null),
      );

      if (!mounted) return;

      setState(() {
        _items = _filterLocally(items);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _items = const <ZohoInvoice>[];
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<ZohoInvoice> _filterLocally(List<ZohoInvoice> items) {
    final String account = (_scopeAccountNumber ?? '').trim();
    final String patientId = _scopePatientId;

    if (account.isEmpty && patientId.isEmpty) return items;

    return items
        .where((ZohoInvoice invoice) {
          final String invoiceAccount = (invoice.accountNumber ?? '').trim();

          if (account.isNotEmpty && invoiceAccount.isNotEmpty) {
            return invoiceAccount == account;
          }

          final String haystack = <String?>[
            invoice.accountNumber,
            invoice.invoiceId,
            invoice.invoiceNumber,
            invoice.customerName,
            invoice.notes,
          ].whereType<String>().join(' ').toLowerCase();

          final String needle = account.isNotEmpty ? account : patientId;

          return haystack.contains(needle.toLowerCase());
        })
        .toList(growable: false);
  }

  String? _cleanOrNull(String? value) {
    final String clean = (value ?? '').trim();
    return clean.isEmpty ? null : clean;
  }

  bool _contains(String source, String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    return source.toLowerCase().contains(q);
  }

  List<ZohoInvoice> _visibleItems() {
    final String q = _searchCtl.text.trim();

    return _items
        .where((ZohoInvoice invoice) {
          final String haystack = <String?>[
            invoice.invoiceId,
            invoice.invoiceNumber,
            invoice.customerName,
            invoice.status,
            invoice.accountNumber,
            invoice.currencyCode,
            invoice.notes,
            invoice.total.toString(),
            invoice.balance?.toString(),
          ].whereType<String>().join(' ');

          return _contains(haystack, q);
        })
        .toList(growable: false);
  }

  void _select(ZohoInvoice invoice) {
    final String invoiceId = invoice.invoiceId.trim();
    if (invoiceId.isEmpty) return;

    setState(() {
      _selectedInvoiceId = invoiceId;
    });

    widget.onSelected?.call(invoice);
  }

  @override
  Widget build(BuildContext context) {
    final List<ZohoInvoice> invoices = _visibleItems();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Header(
              title: widget.title,
              count: invoices.length,
              isLoading: _loading,
              onRefresh: _load,
            ),
            const SizedBox(height: 12),
            _SearchBox(
              controller: _searchCtl,
              onChanged: (_) => setState(() {}),
              onRefresh: _load,
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              _ErrorText(_error!),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: _loading && invoices.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : invoices.isEmpty
                  ? _EmptyText(
                      text:
                          widget.emptyText ??
                          'No invoices found for this patient.',
                    )
                  : ListView.separated(
                      itemCount: invoices.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final ZohoInvoice invoice = invoices[index];

                        final bool selected =
                            invoice.invoiceId.trim() ==
                            (_selectedInvoiceId ?? '').trim();

                        return _InvoiceTile(
                          invoice: invoice,
                          selected: selected,
                          onTap: () => _select(invoice),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class InvoicePickerDialog extends StatelessWidget {
  const InvoicePickerDialog({
    super.key,
    this.initialInvoiceId,
    required this.patientId,
    this.patientNo,
    this.accountNumber,
    this.title = 'Select invoice',
    this.emptyText,
  });

  final String? initialInvoiceId;
  final String patientId;
  final String? patientNo;
  final String? accountNumber;
  final String title;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 760,
        height: MediaQuery.of(context).size.height * 0.72,
        child: InvoicePickerCard(
          initialInvoiceId: initialInvoiceId,
          patientId: patientId,
          patientNo: patientNo,
          accountNumber: accountNumber,
          emptyText: emptyText,
          onSelected: (ZohoInvoice invoice) {
            Navigator.of(context).pop(invoice);
          },
        ),
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(null),
          icon: const Icon(Icons.close),
          label: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.count,
    required this.isLoading,
    required this.onRefresh,
  });

  final String title;
  final int count;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                count == 1
                    ? '1 invoice available.'
                    : '$count invoices available.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh invoices',
          onPressed: isLoading ? null : onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.onChanged,
    required this.onRefresh,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        labelText: 'Search invoices',
        hintText: 'Invoice no, customer, amount, status...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          tooltip: 'Search',
          onPressed: onRefresh,
          icon: const Icon(Icons.arrow_forward),
        ),
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
      onSubmitted: (_) => onRefresh(),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({
    required this.invoice,
    required this.selected,
    required this.onTap,
  });

  final ZohoInvoice invoice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return ListTile(
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.35),
      leading: CircleAvatar(
        backgroundColor: selected ? scheme.primaryContainer : null,
        foregroundColor: selected ? scheme.onPrimaryContainer : null,
        child: Icon(selected ? Icons.check : Icons.receipt_long_outlined),
      ),
      title: Text(
        _title(invoice),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _subtitle(invoice),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: FilledButton(
        onPressed: onTap,
        child: Text(selected ? 'Selected' : 'Use'),
      ),
      onTap: onTap,
    );
  }

  static String _title(ZohoInvoice invoice) {
    final String number = (invoice.invoiceNumber ?? '').trim();
    final String id = invoice.invoiceId.trim();

    return number.isNotEmpty ? number : id;
  }

  static String _subtitle(ZohoInvoice invoice) {
    final List<String> parts = <String>[
      invoice.customerName,
      invoice.status,
      if (invoice.date != null) _formatDate(invoice.date!),
      '${invoice.currencyCode ?? ''} ${invoice.total}',
      if (invoice.balance != null) 'Balance ${invoice.balance}',
      if ((invoice.accountNumber ?? '').trim().isNotEmpty)
        'Account ${invoice.accountNumber!.trim()}',
    ];

    return parts.where((String p) => p.trim().isNotEmpty).join(' · ');
  }

  static String _formatDate(DateTime value) {
    final DateTime local = value.toLocal();

    String two(int v) => v.toString().padLeft(2, '0');

    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.receipt_long_outlined, size: 42),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
