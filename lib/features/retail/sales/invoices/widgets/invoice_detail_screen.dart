// lib/features/retail/sales/invoices/widgets/invoice_detail_screen.dart

import 'package:afyakit/core/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth_user/providers/current_user_providers.dart';

import 'package:afyakit/features/retail/sales/invoices/controllers/invoice_controller.dart';
import 'package:afyakit/features/retail/sales/invoices/controllers/invoice_state.dart';
import 'package:afyakit/features/retail/sales/invoices/models/zoho_invoice.dart';
import 'package:afyakit/features/retail/sales/invoices/models/zoho_invoice_payment.dart';

import 'package:afyakit/features/retail/sales/widgets/sales_doc_body.dart';
import 'package:afyakit/features/retail/sales/widgets/sales_doc_header.dart';

import 'package:afyakit/shared/layout/app_page_scaffold.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/pdf/pdf_preview_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final _nf = NumberFormat.decimalPattern();
final _ymd = DateFormat('yyyy-MM-dd');

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _booted = false;
  bool _acting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref.read(invoiceControllerProvider.notifier).load(widget.invoiceId);
    });
  }

  // ─────────────────────────────────────────────
  // Actions (PDF) — match QuoteDetailScreen style
  // ─────────────────────────────────────────────

  Future<void> _runAction(Future<void> Function() fn) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await fn();
    } catch (e) {
      SnackService.showError(e.toString());
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _viewPdf(InvoiceController ctl) async {
    await _runAction(() async {
      // ✅ Use controller (same approach as quotes)
      final bytes = await ctl.getInvoicePdfBytes(widget.invoiceId);
      if (bytes == null) return;

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            bytes: bytes,
            title: 'Invoice PDF',
            fileName: 'invoice_${widget.invoiceId}.pdf',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final canManageInvoices = me?.canManageInvoices ?? false;

    final s = ref.watch(invoiceControllerProvider);
    final ctl = ref.read(invoiceControllerProvider.notifier);

    const title = 'Invoice';

    final pdfBusy = _acting || s.downloadingPdf;

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text(title),
        actions: [
          IconButton(
            tooltip: pdfBusy ? 'Working…' : 'PDF',
            onPressed: pdfBusy ? null : () => _viewPdf(ctl),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: s.busy ? null : () => ctl.load(widget.invoiceId),
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: s.busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      scrollable: false,
      body: _buildBody(context, s, ctl, canManageInvoices: canManageInvoices),
    );
  }

  Widget _buildBody(
    BuildContext context,
    InvoiceState s,
    InvoiceController ctl, {
    required bool canManageInvoices,
  }) {
    if (s.loading && !s.hasInvoice) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!s.hasInvoice) {
      return _ErrorState(
        title: 'Failed to load invoice',
        message: (s.error ?? 'No invoice data'),
      );
    }

    final ZohoInvoice inv = s.invoice!;

    final meta = SalesDocMetaVm(
      partyName: (inv.customerName).trim().isEmpty
          ? 'Customer'
          : inv.customerName.trim(),
      docNumberOrId: _docNo(inv),
      status: (inv.status).trim(),
      currencyCode: (inv.currencyCode ?? 'KES').trim().isEmpty
          ? 'KES'
          : inv.currencyCode!.trim(),
      total: inv.total,
      date: inv.date,
    );

    final lines = inv.lineItems
        .map(
          (li) => SalesDocLineVm(
            title: (li.description ?? '').trim().isNotEmpty
                ? (li.description ?? '').trim()
                : li.name.trim(),
            subtitle: _subtitle(li),
            qty: li.quantity,
            rate: li.rate,
          ),
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if ((s.error ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _InlineError(message: s.error!.trim()),
          ),
        SalesDocHeader(title: 'Invoice', meta: meta),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 0, bottom: 96),
            children: [
              SizedBox(
                height: 420,
                child: SalesDocLinesList(
                  currencyCode: meta.currencyCode,
                  lines: lines,
                  mode: SalesDocMode.view,
                ),
              ),
              SalesDocTotalBar(
                label: 'Total',
                total: meta.total,
                currencyCode: meta.currencyCode,
              ),
              const SizedBox(height: AppShape.gap12),
              const Divider(height: 1),
              const SizedBox(height: AppShape.gap12),
              _PaymentsSection(
                currencyCode: meta.currencyCode,
                state: s,
                ctl: ctl,
                canManageInvoices: canManageInvoices,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _docNo(ZohoInvoice inv) {
    final n = (inv.invoiceNumber ?? '').trim();
    if (n.isNotEmpty) return n;
    final id = inv.invoiceId.trim();
    return id.isEmpty ? '-' : id;
  }

  static String? _subtitle(ZohoInvoiceLineItem li) {
    final name = li.name.trim();
    final desc = (li.description ?? '').trim();
    final title = desc.isNotEmpty ? desc : name;
    if (desc.isNotEmpty && name.isNotEmpty && name != title) return name;
    return null;
  }
}

// ─────────────────────────────────────────────
// Payments UI (unchanged)
// ─────────────────────────────────────────────

class _PaymentsSection extends StatelessWidget {
  const _PaymentsSection({
    required this.currencyCode,
    required this.state,
    required this.ctl,
    required this.canManageInvoices,
  });

  final String currencyCode;
  final InvoiceState state;
  final InvoiceController ctl;
  final bool canManageInvoices;

  @override
  Widget build(BuildContext context) {
    final s = state;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Payments',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              IconButton(
                tooltip: 'Refresh payments',
                onPressed: s.busy ? null : ctl.refreshPayments,
                icon: const Icon(Icons.refresh),
              ),
              if (canManageInvoices)
                FilledButton.icon(
                  onPressed: s.busy
                      ? null
                      : () {
                          ctl.startNewPayment();
                          _openPaymentSheet(context);
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('Record'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (s.loadingPayments && s.payments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!s.hasPayments)
            Text(
              'No payments recorded.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Column(
              children: [
                for (final p in s.payments) ...[
                  _PaymentTile(
                    currencyCode: currencyCode,
                    p: p,
                    canManage: canManageInvoices,
                    onEdit: () {
                      ctl.startEditPayment(p);
                      _openPaymentSheet(context);
                    },
                    onDelete: () async {
                      final ok = await _confirmDelete(context);
                      if (!ok) return;
                      await ctl.deletePayment(p.paymentId);
                    },
                    busy: s.busy,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Future<void> _openPaymentSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PaymentEditorSheet(),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete payment?'),
        content: const Text('This will remove the payment in Zoho Books.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return res ?? false;
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.currencyCode,
    required this.p,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
    required this.busy,
  });

  final String currencyCode;
  final ZohoInvoicePayment p;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final date = p.date == null ? '—' : _ymd.format(p.date!);
    final mode = (p.mode ?? '').trim().isEmpty ? 'Payment' : p.mode!.trim();
    final ref = (p.referenceNumber ?? '').trim();
    final amount = '$currencyCode ${_nf.format(p.amount)}';

    return Material(
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: canManage && !busy ? onEdit : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              const Icon(Icons.payments_outlined, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ref.isEmpty ? date : '$date • $ref',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(amount, style: const TextStyle(fontWeight: FontWeight.w800)),
              if (canManage) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Delete payment',
                  onPressed: busy ? null : onDelete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentEditorSheet extends ConsumerStatefulWidget {
  const _PaymentEditorSheet();

  @override
  ConsumerState<_PaymentEditorSheet> createState() =>
      _PaymentEditorSheetState();
}

class _PaymentEditorSheetState extends ConsumerState<_PaymentEditorSheet> {
  late final TextEditingController _amountCtl;
  late final TextEditingController _dateCtl;
  late final TextEditingController _modeCtl;
  late final TextEditingController _refCtl;
  late final TextEditingController _descCtl;

  @override
  void initState() {
    super.initState();
    final s = ref.read(invoiceControllerProvider);

    _amountCtl = TextEditingController(text: s.paymentDraft.amount.toString());
    _dateCtl = TextEditingController(text: _ymd.format(s.paymentDraft.date));
    _modeCtl = TextEditingController(text: (s.paymentDraft.mode ?? '').trim());
    _refCtl = TextEditingController(
      text: (s.paymentDraft.referenceNumber ?? '').trim(),
    );
    _descCtl = TextEditingController(
      text: (s.paymentDraft.description ?? '').trim(),
    );
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _dateCtl.dispose();
    _modeCtl.dispose();
    _refCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(invoiceControllerProvider);
    final ctl = ref.read(invoiceControllerProvider.notifier);

    final isEdit = s.isEditingPayment;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isEdit ? 'Edit payment' : 'Record payment',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amountCtl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) =>
                ctl.patchPaymentDraft(amount: num.tryParse(v.trim())),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _dateCtl,
            decoration: const InputDecoration(
              labelText: 'Date (YYYY-MM-DD)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              final t = v.trim();
              final dt = DateTime.tryParse(t);
              if (dt != null) ctl.patchPaymentDraft(date: dt);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _modeCtl,
            decoration: const InputDecoration(
              labelText: 'Mode (e.g. Cash, Mpesa, Bank Transfer)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => ctl.patchPaymentDraft(mode: v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _refCtl,
            decoration: const InputDecoration(
              labelText: 'Reference number (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => ctl.patchPaymentDraft(referenceNumber: v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descCtl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => ctl.patchPaymentDraft(description: v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: s.busy
                      ? null
                      : () {
                          ctl.cancelPaymentEdit();
                          Navigator.pop(context);
                        },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: s.busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(s.busy ? 'Saving…' : 'Save'),
                  onPressed: s.busy
                      ? null
                      : () async {
                          final ok = await ctl.savePayment();
                          if (!ok) return;
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44),
              const SizedBox(height: 12),
              Text(title, style: t.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message, style: t.bodyMedium, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
