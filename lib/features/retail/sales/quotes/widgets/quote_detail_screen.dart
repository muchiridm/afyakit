// lib/features/retail/quotes/widgets/quote_detail_screen.dart

import 'package:afyakit/shared/widgets/pdf/pdf_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/layout/app_page_scaffold.dart';
import 'package:afyakit/shared/services/snack_service.dart';

import 'package:afyakit/features/retail/sales/quotes/models/zoho_quote.dart';
import 'package:afyakit/features/retail/sales/quotes/services/zoho_quotes_service.dart';
import 'package:afyakit/features/retail/sales/quotes/widgets/quote_editor_screen.dart';
import 'package:afyakit/features/retail/sales/quotes/widgets/quotes_list_screen.dart';

import 'package:afyakit/features/retail/sales/widgets/sales_doc_body.dart';
import 'package:afyakit/features/retail/sales/widgets/sales_doc_header.dart';

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
  // Actions
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
    await _runAction(() async {
      await svc.sendQuote(widget.quoteId);
      SnackService.showSuccess('Quote sent');
    });
  }

  Future<void> _markSent(ZohoQuotesService svc) async {
    await _runAction(() async {
      await svc.markQuoteSent(widget.quoteId);
      SnackService.showSuccess('Marked as sent');
    });
  }

  Future<void> _convertToInvoice(ZohoQuotesService svc) async {
    await _runAction(() async {
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
      loading: () => _buildShell(
        context,
        title: 'Quote',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _buildShell(
        context,
        title: 'Quote',
        body: _ErrorState(title: 'Zoho service failed', message: '$e'),
      ),
      data: (svc) => FutureBuilder<ZohoQuote>(
        future: svc.get(widget.quoteId), // ✅ typed now
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _buildShell(
              context,
              title: 'Quote',
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          if (snap.hasError) {
            return _buildShell(
              context,
              title: 'Quote',
              body: _ErrorState(
                title: 'Failed to load quote',
                message: '${snap.error ?? 'Unknown error'}',
              ),
            );
          }

          final q = snap.data;
          if (q == null) {
            return _buildShell(
              context,
              title: 'Quote',
              body: const _ErrorState(
                title: 'Failed to load quote',
                message: 'No data returned',
              ),
            );
          }

          return _buildDetail(context, svc, q);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Common shell
  // ─────────────────────────────────────────────

  Widget _buildShell(
    BuildContext context, {
    required String title,
    required Widget body,
    List<Widget> actions = const [],
  }) {
    return AppPageScaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      scrollable: false,
      body: body,
    );
  }

  // ─────────────────────────────────────────────
  // Detail UI (SalesDoc widgets)
  // ─────────────────────────────────────────────

  Widget _buildDetail(
    BuildContext context,
    ZohoQuotesService svc,
    ZohoQuote q,
  ) {
    final meta = SalesDocMetaVm(
      partyName: (q.customerName.trim().isEmpty ? 'Customer' : q.customerName),
      docNumberOrId: q.referenceNumber?.trim().isNotEmpty == true
          ? q.referenceNumber!.trim()
          : q.quoteId,
      status: q.status,
      currencyCode: q.currencyCode ?? '',
      total: q.total,
      date: q.date,
    );

    final lines = q.lineItems
        .map((li) {
          // Prefer description as title, fallback to name
          final title =
              _cleanZohoLineText(li.description) ??
              _cleanZohoLineText(li.name) ??
              '';

          final subtitle =
              (li.description != null &&
                  _cleanZohoLineText(li.description) != null &&
                  _cleanZohoLineText(li.name) != null &&
                  _cleanZohoLineText(li.description) !=
                      _cleanZohoLineText(li.name))
              ? _cleanZohoLineText(li.name)
              : null;

          return SalesDocLineVm(
            title: title,
            subtitle: subtitle,
            qty: li.quantity,
            rate: li.rate,
          );
        })
        .toList(growable: false);

    final actions = <Widget>[
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
      ),
      IconButton(
        tooltip: 'Edit quote',
        icon: const Icon(Icons.edit_outlined),
        onPressed: _acting ? null : () => _editQuote(context),
      ),
    ];

    return _buildShell(
      context,
      title: 'Quote',
      actions: actions,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SalesDocHeader(title: 'Quote', meta: meta),
          const Divider(height: 1),
          Expanded(
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
        ],
      ),
    );
  }

  /// Treat Zoho placeholder "Item" as empty; return null if empty.
  static String? _cleanZohoLineText(Object? v) {
    final t = (v ?? '').toString().trim();
    if (t.isEmpty) return null;
    if (t.toLowerCase() == 'item') return null;
    return t;
  }
}

enum _QuoteAction { send, markSent, invoice }

// ─────────────────────────────────────────────
// Small UI helper
// ─────────────────────────────────────────────

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
