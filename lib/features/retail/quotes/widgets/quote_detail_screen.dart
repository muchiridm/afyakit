// lib/features/retail/sales/quotes/widgets/quote_detail_screen.dart

import 'package:afyakit/features/retail/quotes/models/zoho_quote_line_item.dart';
import 'package:afyakit/features/retail/shared/sales_doc/totals.dart';
import 'package:afyakit/shared/widgets/pdf/pdf_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/services/snack_service.dart';

import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';
import 'package:afyakit/features/retail/quotes/services/zoho_quotes_service.dart';
import 'package:afyakit/features/retail/quotes/widgets/quote_editor_screen.dart';

import 'package:afyakit/features/retail/shared/sales_doc/dialogs.dart';
import 'package:afyakit/features/retail/shared/sales_doc/feedback.dart';
import 'package:afyakit/features/retail/shared/sales_doc/header.dart';
import 'package:afyakit/features/retail/shared/sales_doc/lines.dart';
import 'package:afyakit/features/retail/shared/sales_doc/models.dart';
import 'package:afyakit/features/retail/shared/sales_doc/status.dart';

enum _QuoteAction { send, markSent, invoice }

/// Riverpod-native quote loader.
/// ✅ Refreshable (`ref.refresh(...)`)
final zohoQuoteProvider = FutureProvider.autoDispose.family<ZohoQuote, String>((
  ref,
  quoteId,
) async {
  final svc = await ref.watch(zohoQuotesServiceProvider.future);
  return svc.get(quoteId);
});

class QuoteDetailScreen extends ConsumerStatefulWidget {
  const QuoteDetailScreen({super.key, required this.quoteId});
  final String quoteId;

  @override
  ConsumerState<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends ConsumerState<QuoteDetailScreen> {
  bool _acting = false;

  // ─────────────────────────────────────────────
  // Action runner
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

  // ─────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────

  Future<void> _editQuote(BuildContext context) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuoteEditorScreen(editingQuoteId: widget.quoteId),
      ),
    );

    if (!mounted) return;

    // ✅ stay on this screen; just refresh the quote
    if (changed == true) {
      ref.invalidate(zohoQuoteProvider(widget.quoteId));
      SnackService.showSuccess('Quote refreshed');
    }
  }

  // ─────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────

  Future<void> _viewPdf(ZohoQuotesService svc) async {
    await _runAction(() async {
      final bytes = await svc.getPdf(widget.quoteId);
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            bytes: bytes,
            title: 'Quote PDF',
            fileName: 'quote_${widget.quoteId}.pdf',
          ),
        ),
      );
    });
  }

  Future<void> _send(ZohoQuotesService svc) async {
    final ok = await SalesDocDialogs.confirm(
      context,
      title: 'Send quote?',
      message: 'This will email the quote to the customer.',
      okLabel: 'Send',
      danger: false,
      barrierDismissible: false,
    );
    if (!ok) return;

    await _runAction(() async {
      await svc.email(widget.quoteId);
      SnackService.showSuccess('Quote sent');

      // Optional: status may change; refresh the detail.
      ref.invalidate(zohoQuoteProvider(widget.quoteId));
    });
  }

  Future<void> _markSent(ZohoQuotesService svc) async {
    final ok = await SalesDocDialogs.confirm(
      context,
      title: 'Mark as sent?',
      message: 'This will update the quote status in Zoho Books.',
      okLabel: 'Mark sent',
      danger: false,
      barrierDismissible: false,
    );
    if (!ok) return;

    await _runAction(() async {
      await svc.markSent(widget.quoteId);
      SnackService.showSuccess('Marked as sent');
      ref.invalidate(zohoQuoteProvider(widget.quoteId));
    });
  }

  Future<void> _convertToInvoice(ZohoQuotesService svc) async {
    final ok = await SalesDocDialogs.confirm(
      context,
      title: 'Convert to invoice?',
      message: 'This will create an invoice from this quote in Zoho Books.',
      okLabel: 'Convert',
      danger: false,
      barrierDismissible: false,
    );
    if (!ok) return;

    await _runAction(() async {
      final res = await svc.convertToInvoice(widget.quoteId);

      // Don’t assume exact response shape; show something useful if present.
      final invoiceId = (res['invoice_id'] ?? res['invoiceId'] ?? '')
          .toString();
      final invoiceNumber =
          (res['invoice_number'] ?? res['invoiceNumber'] ?? '').toString();

      if (invoiceNumber.trim().isNotEmpty) {
        SnackService.showSuccess('Converted → Invoice $invoiceNumber');
      } else if (invoiceId.trim().isNotEmpty) {
        SnackService.showSuccess('Converted → Invoice $invoiceId');
      } else {
        SnackService.showSuccess('Converted to invoice');
      }

      // Quote may change status; refresh.
      ref.invalidate(zohoQuoteProvider(widget.quoteId));
    });
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final quoteAsync = ref.watch(zohoQuoteProvider(widget.quoteId));
    final svcAsync = ref.watch(zohoQuotesServiceProvider);

    return AppPage(
      title: 'Quote',
      showBack: true,
      scrollable: false,
      actions: svcAsync.maybeWhen(
        data: (svc) => _buildConstrainedActions(svc),
        orElse: () => const <Widget>[],
      ),
      body: quoteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => SalesDocErrorState(
          title: 'Failed to load quote',
          message: e.toString(),
        ),
        data: (q) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(zohoQuoteProvider(widget.quoteId));
            // Wait for reload so indicator feels correct
            await ref.read(zohoQuoteProvider(widget.quoteId).future);
          },
          child: _buildDetail(context, q),
        ),
      ),
    );
  }

  List<Widget> _buildConstrainedActions(ZohoQuotesService svc) {
    return [
      IconButton(
        tooltip: _acting ? 'Working…' : 'PDF',
        icon: const Icon(Icons.picture_as_pdf_outlined),
        onPressed: _acting ? null : () => _viewPdf(svc),
      ),
      PopupMenuButton<_QuoteAction>(
        tooltip: 'Actions',
        enabled: !_acting,
        onSelected: (a) {
          switch (a) {
            case _QuoteAction.send:
              _send(svc);
              break;
            case _QuoteAction.markSent:
              _markSent(svc);
              break;
            case _QuoteAction.invoice:
              _convertToInvoice(svc);
              break;
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: _QuoteAction.send, child: Text('Send quote')),
          PopupMenuItem(
            value: _QuoteAction.markSent,
            child: Text('Mark as sent'),
          ),
          PopupMenuDivider(),
          PopupMenuItem(
            value: _QuoteAction.invoice,
            child: Text('Convert to invoice'),
          ),
        ],
        icon: const Icon(Icons.more_vert),
      ),
      IconButton(
        tooltip: 'Edit quote',
        icon: const Icon(Icons.edit_outlined),
        onPressed: _acting ? null : () => _editQuote(context),
      ),
    ];
  }

  Widget _buildDetail(BuildContext context, ZohoQuote q) {
    final meta = SalesDocMetaVm(
      partyName: q.customerName.trim().isEmpty ? 'Customer' : q.customerName,
      docNumberOrId: (q.accountNumber ?? '').trim().isNotEmpty
          ? q.accountNumber!.trim()
          : q.quoteId,
      status: q.status,
      currencyCode: (q.currencyCode ?? '').trim(),
      total: q.total,
      date: q.date,
      expiryDate: q.expiryDate,
    );

    final currency = _currency(meta.currencyCode);

    final lines = q.lineItems
        .map(
          (li) => SalesDocLineVm(
            title: _lineTitle(li),
            subtitle: _lineSubtitle(li),
            qty: li.quantity,
            rate: li.rate,
          ),
        )
        .toList(growable: false);

    // RefreshIndicator needs a scrollable child.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (_acting) const LinearProgressIndicator(minHeight: 2),
        SalesDocHeader(
          title: '',
          meta: meta,
          showStatus: false,
          trailing: _HeaderStatusPill(status: meta.status),
        ),
        const Divider(height: 1),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: SalesDocLinesList(
            currencyCode: currency,
            lines: lines,
            mode: SalesDocMode.view,
          ),
        ),
        SalesDocTotalBar(
          label: 'Total',
          total: meta.total,
          currencyCode: currency,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  static String _currency(String code) {
    final c = code.trim();
    return c.isEmpty ? 'KES' : c;
  }

  static String _lineTitle(ZohoQuoteLineItem li) {
    final name = _cleanZohoLineText(li.name);
    final v = (name ?? '').trim();
    return v.isEmpty ? 'Item' : v;
  }

  static String? _lineSubtitle(ZohoQuoteLineItem li) {
    final desc = _cleanZohoLineText(li.description);
    final v = (desc ?? '').trim();
    return v.isEmpty ? null : v;
  }

  static String? _cleanZohoLineText(Object? v) {
    final t = (v ?? '').toString().trim();
    if (t.isEmpty) return null;
    if (t.toLowerCase() == 'item') return null;
    return t;
  }
}

/// Matches invoice header trailing vibe (icon + chip).
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
