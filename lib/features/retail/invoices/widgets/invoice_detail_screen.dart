// lib/features/retail/sales/invoices/widgets/invoice_detail_screen.dart

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_user_providers.dart';

import 'package:afyakit/features/retail/invoices/controllers/invoice_controller.dart';
import 'package:afyakit/features/retail/invoices/controllers/invoice_state.dart';
import 'package:afyakit/features/retail/shared/models/zoho_invoice.dart';
import 'package:afyakit/features/retail/shared/models/zoho_email_draft.dart';

import 'package:afyakit/features/retail/shared/widgets/sales_doc_feedback.dart';
import 'package:afyakit/features/retail/shared/widgets/sales_doc_header.dart';
import 'package:afyakit/features/retail/shared/widgets/sales_doc_lines.dart';
import 'package:afyakit/features/retail/shared/widgets/sales_doc_models.dart';
import 'package:afyakit/features/retail/shared/widgets/sales_doc_status_chip.dart';
import 'package:afyakit/features/retail/shared/widgets/sales_doc_total_bar.dart';

import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/services/dialog_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/widgets/pdf/pdf_preview_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../payments/zoho/widgets/payment_footer.dart';

enum _InvoiceMenuAction { send, markSent }

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  static const double _contentMaxW = 720;

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

  Future<void> _sendInvoice(InvoiceController ctl) async {
    final ok = await DialogService.confirm(
      context: context,
      title: 'Send invoice?',
      content: 'This will email the invoice to the customer.',
      confirmText: 'Send',
      confirmColor: Colors.blue,
      barrierDismissible: false,
    );
    if (!ok) return;

    await _runAction(() async {
      final invoice = ctl.publicState.invoice;
      if (invoice == null) return;

      final email = ZohoEmailDraft(
        contactPersonIds: invoice.contactPersonIds,
        subject: 'Invoice ${invoice.invoiceNumber ?? invoice.invoiceId}',
        body: 'Please find your invoice attached.',
      );

      final sent = await ctl.sendInvoice(widget.invoiceId, email: email);
      if (!sent) return;

      await ctl.load(widget.invoiceId);
    });
  }

  Future<void> _markSent(InvoiceController ctl) async {
    final ok = await DialogService.confirm(
      context: context,
      title: 'Mark as sent?',
      content: 'This will update the invoice status in Zoho Books.',
      confirmText: 'Mark sent',
      confirmColor: Colors.blue,
      barrierDismissible: false,
    );
    if (!ok) return;

    await _runAction(() async {
      final done = await ctl.markInvoiceSent(widget.invoiceId);
      if (!done) return;

      await ctl.load(widget.invoiceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final canManageInvoices = me?.canManageInvoices ?? false;

    final s = ref.watch(invoiceControllerProvider);
    final ctl = ref.read(invoiceControllerProvider.notifier);

    final pdfBusy = _acting || s.downloadingPdf;
    final menuBusy = _acting || s.busy;

    return AppPage(
      title: 'Invoice',
      showBack: true,
      maxWidth: _contentMaxW,
      scrollable: true,

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
        if (canManageInvoices)
          PopupMenuButton<_InvoiceMenuAction>(
            tooltip: 'More',
            enabled: !menuBusy,
            onSelected: (a) async {
              switch (a) {
                case _InvoiceMenuAction.send:
                  await _sendInvoice(ctl);
                  break;
                case _InvoiceMenuAction.markSent:
                  await _markSent(ctl);
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<_InvoiceMenuAction>(
                value: _InvoiceMenuAction.send,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.send_outlined),
                  title: Text('Send invoice'),
                ),
              ),
              PopupMenuItem<_InvoiceMenuAction>(
                value: _InvoiceMenuAction.markSent,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.mark_email_read_outlined),
                  title: Text('Mark as sent'),
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
      ],

      body: _buildBody(context, s, canManageInvoices: canManageInvoices),
      footer: null,
    );
  }

  Widget _buildBody(
    BuildContext context,
    InvoiceState s, {
    required bool canManageInvoices,
  }) {
    if (s.loading && !s.hasInvoice) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!s.hasInvoice) {
      return SalesDocErrorState(
        title: 'Failed to load invoice',
        message: (s.error ?? 'No invoice data'),
      );
    }

    final ZohoInvoice inv = s.invoice!;
    final currency = _currency(inv);

    final meta = SalesDocMetaVm(
      partyName: _partyName(inv),
      docNumberOrId: _docNo(inv),
      status: (inv.status).trim(),
      currencyCode: currency,
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

    final num? balance = inv.balance;
    final num paid = (balance == null) ? 0 : (inv.total - balance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.busy) const LinearProgressIndicator(minHeight: 2),
        InlineErrorCard(message: (s.error ?? '').trim()),

        // ✅ Remove repetition:
        // - disable SalesDocHeader's built-in status pill row
        // - keep the trailing status (icon + chip) only once
        SalesDocHeader(
          title: 'Invoice', // optionally set '' to remove subtitle repetition
          meta: meta,
          showStatus: false, // ✅ this kills the duplicate "paid" pill row item
          trailing: _HeaderStatusPill(status: meta.status),
        ),

        const Divider(height: 1),

        SalesDocLinesList(
          currencyCode: meta.currencyCode,
          lines: lines,
          mode: SalesDocMode.view,
          embedInParentScroll: true,
        ),

        SalesDocTotalsStack(
          currencyCode: meta.currencyCode,
          total: meta.total,
          paid: paid > 0 ? paid : null,
          balance: balance,
        ),

        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),

        PaymentFooter(
          currencyCode: currency,
          invoiceId: inv.invoiceId,
          canManageInvoices: canManageInvoices,
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  static String _currency(ZohoInvoice inv) {
    final raw = (inv.currencyCode ?? 'KES').trim();
    return raw.isEmpty ? 'KES' : raw;
  }

  static String _partyName(ZohoInvoice inv) {
    final n = inv.customerName.trim();
    return n.isEmpty ? 'Customer' : n;
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

/// Small header trailing widget:
/// - matches list vibe (icon + chip)
/// - doesn't mess with SalesDocHeader internals
class _HeaderStatusPill extends StatelessWidget {
  const _HeaderStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.trim();
    if (s.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SalesDocLeadingIcon(status: s, radius: 14),
        const SizedBox(width: 8),
        SalesDocStatusChip(status: s),
      ],
    );
  }
}
