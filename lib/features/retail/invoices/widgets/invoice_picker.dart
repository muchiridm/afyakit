// lib/features/retail/sales/invoices/widgets/invoice_picker.dart

import 'package:afyakit/features/retail/invoices/models/zoho_invoice.dart';
import 'package:afyakit/features/retail/invoices/services/zoho_invoices_service.dart';
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

  /// Patient scope for clinical / insurance workflows.
  ///
  /// This may be an internal patient id or patient number depending on the
  /// calling screen. The backend can use it as patient_id.
  final String patientId;

  /// Preferred patient number. For insurance invoices this is usually the
  /// most reliable key because Zoho has cf_patient_no.
  final String? patientNo;

  /// Optional explicit customer/member account scope.
  ///
  /// Important:
  /// Do not pass patientNo here. Account number is a customer/contact scope.
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

  String? get _scopePatientNo {
    final String value = (widget.patientNo ?? '').trim();
    return value.isEmpty ? null : value;
  }

  String? get _scopeAccountNumber {
    final String value = (widget.accountNumber ?? '').trim();
    return value.isEmpty ? null : value;
  }

  bool get _hasScope {
    return _scopePatientId.isNotEmpty ||
        (_scopePatientNo ?? '').isNotEmpty ||
        (_scopeAccountNumber ?? '').isNotEmpty;
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
      setState(() {
        _items = const <ZohoInvoice>[];
        _selectedInvoiceId = nextInitialId;
        _error = null;
      });

      Future<void>.microtask(_load);
    }
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_hasScope) {
      if (!mounted) return;

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
        q: search.isEmpty ? null : search,

        // Explicit account/customer scope only.
        accountNumber: _scopeAccountNumber,

        // Patient/claim context. This is what allows insurer-addressed
        // invoices to still appear in claim-pack workflows.
        patientId: _scopePatientId.isEmpty ? null : _scopePatientId,
        patientNo: _scopePatientNo,
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
        _error = _friendlyError(e);
      });
    }
  }

  List<ZohoInvoice> _filterLocally(List<ZohoInvoice> items) {
    final String account = (_scopeAccountNumber ?? '').trim();
    final String patientId = _scopePatientId;
    final String patientNo = (_scopePatientNo ?? '').trim();

    if (account.isEmpty && patientId.isEmpty && patientNo.isEmpty) {
      return items;
    }

    return items
        .where((ZohoInvoice invoice) {
          final String invoiceAccount = (invoice.accountNumber ?? '').trim();

          if (account.isNotEmpty) {
            if (invoiceAccount.isEmpty) return false;
            return _same(invoiceAccount, account);
          }

          final List<String> needles = <String>[
            patientId,
            patientNo,
          ].where((String value) => value.trim().isNotEmpty).toList();

          if (needles.isEmpty) return true;

          final String haystack = <String?>[
            invoice.accountNumber,
            invoice.invoiceId,
            invoice.invoiceNumber,
            invoice.customerName,
            invoice.notes,
            invoice.resolvedPatientId,
            invoice.resolvedPatientNo,
            invoice.resolvedPatientName,
            invoice.resolvedMembershipId,
            invoice.resolvedPrescriptionId,
            invoice.resolvedClaimPackId,
          ].whereType<String>().join(' ').toLowerCase();

          return needles.any((String needle) {
            final String n = needle.trim().toLowerCase();
            if (n.isEmpty) return false;

            return haystack.contains(n);
          });
        })
        .toList(growable: false);
  }

  String? _cleanOrNull(String? value) {
    final String clean = (value ?? '').trim();
    return clean.isEmpty ? null : clean;
  }

  bool _same(String a, String b) {
    return a.trim().toLowerCase() == b.trim().toLowerCase();
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
            invoice.resolvedPatientId,
            invoice.resolvedPatientNo,
            invoice.resolvedPatientName,
            invoice.resolvedMembershipId,
            invoice.resolvedPrescriptionId,
            invoice.resolvedClaimPackId,
            invoice.resolvedPaymentContext,
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

  String _emptyText() {
    if (!_hasScope) {
      return 'Select a patient or membership first.';
    }

    return widget.emptyText ?? 'No invoices found for this patient.';
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
              enabled: !_loading,
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
                  ? _EmptyText(text: _emptyText())
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

  static String _friendlyError(Object error) {
    final String raw = error.toString().trim();

    if (raw.isEmpty) return 'Failed to load invoices';

    return raw
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^StateError:\s*'), '')
        .replaceFirst(RegExp(r'^Bad state:\s*'), '')
        .trim();
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
          title: title,
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
    required this.enabled,
    required this.onChanged,
    required this.onRefresh,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        labelText: 'Search invoices',
        hintText: 'Invoice no, customer, patient, claim pack, amount...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          tooltip: 'Search',
          onPressed: enabled ? onRefresh : null,
          icon: const Icon(Icons.arrow_forward),
        ),
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
      onSubmitted: (_) {
        if (enabled) onRefresh();
      },
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
      '${invoice.currencyCode ?? ''} ${invoice.total}'.trim(),
      if (invoice.balance != null) 'Balance ${invoice.balance}',
      if ((invoice.accountNumber ?? '').trim().isNotEmpty)
        'Account ${invoice.accountNumber!.trim()}',
      if (invoice.resolvedPatientNo != null)
        'Patient ${invoice.resolvedPatientNo}',
      if (invoice.resolvedPatientName != null) invoice.resolvedPatientName!,
      if (invoice.hasClaimPack) 'Claim pack linked',
      if (invoice.isInsurancePayment) 'Insurance',
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
