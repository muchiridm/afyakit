// lib/features/retail/sales/quotes/widgets/quote_detail_screen.dart

import 'package:afyakit/features/retail/shared/sales_doc/totals.dart';
import 'package:afyakit/shared/widgets/pdf/pdf_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/services/snack_service.dart';

import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';
import 'package:afyakit/features/retail/quotes/services/zoho_quotes_service.dart';
import 'package:afyakit/features/retail/quotes/widgets/quote_editor_screen.dart';
import 'package:afyakit/features/retail/quotes/widgets/quotes_list_screen.dart';

import 'package:afyakit/features/retail/shared/sales_doc/dialogs.dart';
import 'package:afyakit/features/retail/shared/sales_doc/feedback.dart';
import 'package:afyakit/features/retail/shared/sales_doc/header.dart';
import 'package:afyakit/features/retail/shared/sales_doc/lines.dart';
import 'package:afyakit/features/retail/shared/sales_doc/models.dart';
import 'package:afyakit/features/retail/shared/sales_doc/status.dart';

enum _QuoteAction { send, markSent, invoice }

class QuoteDetailScreen extends ConsumerStatefulWidget {
  const QuoteDetailScreen({super.key, required this.quoteId});
  final String quoteId;

  @override
  ConsumerState<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends ConsumerState<QuoteDetailScreen> {
  bool _acting = false;

  // ─────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────

  Future<void> _editQuote(BuildContext context) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuoteEditorScreen(editingQuoteId: widget.quoteId),
      ),
    );

    if (!context.mounted) return;

    if (changed == true) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const QuotesListScreen()),
        (_) => false,
      );
    }
  }

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
      // ✅ aligned to service: email()
      await svc.email(widget.quoteId);
      SnackService.showSuccess('Quote sent');
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
      // ✅ aligned to service: markSent()
      await svc.markSent(widget.quoteId);
      SnackService.showSuccess('Marked as sent');
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
      // ✅ aligned to service: convertToInvoice()
      await svc.convertToInvoice(widget.quoteId);
      SnackService.showSuccess('Converted to invoice');
    });
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final svcAsync = ref.watch(zohoQuotesServiceProvider);

    return svcAsync.when(
      loading: () => AppPage(
        title: 'Quote',
        showBack: true,
        scrollable: false,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppPage(
        title: 'Quote',
        showBack: true,
        scrollable: false,
        body: SalesDocErrorState(
          title: 'Zoho service failed',
          message: e.toString(),
        ),
      ),
      data: (svc) => _QuoteLoader(
        quoteId: widget.quoteId,
        svc: svc,
        builder: (q) => AppPage(
          title: 'Quote',
          showBack: true,
          scrollable: false,
          actions: _buildConstrainedActions(svc),
          body: _buildDetail(q),
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

  Widget _buildDetail(ZohoQuote q) {
    final meta = SalesDocMetaVm(
      partyName: q.customerName.trim().isEmpty ? 'Customer' : q.customerName,
      docNumberOrId: (q.referenceNumber ?? '').trim().isNotEmpty
          ? q.referenceNumber!.trim()
          : q.quoteId,
      status: q.status,
      currencyCode: (q.currencyCode ?? '').trim(),
      total: q.total,
      date: q.date,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_acting) const LinearProgressIndicator(minHeight: 2),

        SalesDocHeader(
          title: '',
          meta: meta,
          showStatus: false,
          trailing: _HeaderStatusPill(status: meta.status),
        ),

        const Divider(height: 1),

        Expanded(
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

typedef _QuoteBuilder = Widget Function(ZohoQuote quote);

class _QuoteLoader extends StatelessWidget {
  const _QuoteLoader({
    required this.quoteId,
    required this.svc,
    required this.builder,
  });

  final String quoteId;
  final ZohoQuotesService svc;
  final _QuoteBuilder builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ZohoQuote>(
      future: svc.get(quoteId), // ✅ aligned: service has get()
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return SalesDocErrorState(
            title: 'Failed to load quote',
            message: (snap.error ?? 'Unknown error').toString(),
          );
        }

        final q = snap.data;
        if (q == null) {
          return const SalesDocErrorState(
            title: 'Failed to load quote',
            message: 'No data returned',
          );
        }

        return builder(q);
      },
    );
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
