// lib/features/retail/sales/quotes/widgets/quote_detail_screen.dart
// UPDATED: dumb UI (delegates to QuoteActionController), capability-gated via AuthUserX

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';

import 'package:afyakit/features/retail/quotes/extensions/quote_action_enum.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_action_controller.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote_line_item.dart';
import 'package:afyakit/features/retail/quotes/providers/zoho_quote_provider.dart';

import 'package:afyakit/features/retail/shared/sales_doc/feedback.dart';
import 'package:afyakit/features/retail/shared/sales_doc/header.dart';
import 'package:afyakit/features/retail/shared/sales_doc/lines.dart';
import 'package:afyakit/features/retail/shared/sales_doc/models.dart';
import 'package:afyakit/features/retail/shared/sales_doc/status.dart';
import 'package:afyakit/features/retail/shared/sales_doc/totals.dart';

import 'package:afyakit/shared/layout/app_page.dart';

import 'package:afyakit/features/retail/quotes/widgets/quote_editor_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuoteDetailScreen extends ConsumerStatefulWidget {
  const QuoteDetailScreen({super.key, required this.quoteId});
  final String quoteId;

  @override
  ConsumerState<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends ConsumerState<QuoteDetailScreen> {
  bool _acting = false;

  Future<void> _run(Future<void> Function() fn) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _editQuote(
    BuildContext context, {
    required String quoteId,
  }) async {
    final res = await Navigator.of(context).push<QuoteEditorResult>(
      MaterialPageRoute(
        builder: (_) => QuoteEditorScreen(editingQuoteId: quoteId),
      ),
    );

    if (!mounted) return;

    if (res == QuoteEditorResult.deleted) {
      Navigator.of(context).pop(true);
      return;
    }

    if (res == QuoteEditorResult.saved) {
      ref.invalidate(zohoQuoteProvider(quoteId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final quoteId = widget.quoteId.trim();
    if (quoteId.isEmpty) {
      return const AppPage(
        title: 'Quote',
        showBack: true,
        scrollable: false,
        body: SalesDocErrorState(
          title: 'Invalid quote',
          message: 'Missing quote id',
        ),
      );
    }

    final quoteAsync = ref.watch(zohoQuoteProvider(quoteId));
    final me = ref.watch(currentUserProvider).valueOrNull;

    // ✅ New style: gate by capability-derived helper on AuthUserX.
    final canManage = me?.canManageQuotes ?? false;

    final actionsCtl = ref.read(quoteActionControllerProvider);

    return AppPage(
      title: 'Quote',
      showBack: true,
      scrollable: false,
      actions: _buildActions(
        context,
        actionsCtl: actionsCtl,
        canManage: canManage,
        quoteId: quoteId,
      ),
      body: _buildBody(quoteAsync, actionsCtl: actionsCtl, quoteId: quoteId),
    );
  }

  Widget _buildBody(
    AsyncValue<ZohoQuote> quoteAsync, {
    required QuoteActionController actionsCtl,
    required String quoteId,
  }) {
    return quoteAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => SalesDocErrorState(
        title: 'Failed to load quote',
        message: e.toString(),
      ),
      data: (q) => RefreshIndicator(
        onRefresh: () => actionsCtl.refresh(quoteId),
        child: _buildDetail(q),
      ),
    );
  }

  List<Widget> _buildActions(
    BuildContext context, {
    required QuoteActionController actionsCtl,
    required bool canManage,
    required String quoteId,
  }) {
    final actions = <Widget>[
      IconButton(
        tooltip: _acting ? 'Working…' : 'PDF',
        icon: const Icon(Icons.picture_as_pdf_outlined),
        onPressed: _acting
            ? null
            : () => _run(() => actionsCtl.viewPdf(context, quoteId: quoteId)),
      ),
    ];

    if (!canManage) return actions;

    actions.addAll([
      PopupMenuButton<QuoteAction>(
        tooltip: 'Actions',
        enabled: !_acting,
        onSelected: (a) {
          switch (a) {
            case QuoteAction.send:
              _run(() => actionsCtl.sendQuote(context, quoteId: quoteId));
              break;
            case QuoteAction.markSent:
              _run(() => actionsCtl.markSent(context, quoteId: quoteId));
              break;
            case QuoteAction.invoice:
              _run(
                () => actionsCtl.convertToInvoice(context, quoteId: quoteId),
              );
              break;
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: QuoteAction.send, child: Text('Send quote')),
          PopupMenuItem(
            value: QuoteAction.markSent,
            child: Text('Mark as sent'),
          ),
          PopupMenuDivider(),
          PopupMenuItem(
            value: QuoteAction.invoice,
            child: Text('Convert to invoice'),
          ),
        ],
        icon: const Icon(Icons.more_vert),
      ),
      IconButton(
        tooltip: 'Edit quote',
        icon: const Icon(Icons.edit_outlined),
        onPressed: _acting ? null : () => _editQuote(context, quoteId: quoteId),
      ),
    ]);

    return actions;
  }

  Widget _buildDetail(ZohoQuote q) {
    final meta = _buildMeta(q);
    final currency = _currency(meta.currencyCode);
    final lines = _buildLines(q);

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

  static SalesDocMetaVm _buildMeta(ZohoQuote q) {
    final party = q.customerName.trim().isEmpty ? 'Customer' : q.customerName;

    // ✅ ZohoQuote has no quoteNumber (per your compile error).
    // Use what exists: accountNumber (if you use it as doc display) else quoteId.
    final docNo = _bestDocNumber(q);

    final currency = (q.currencyCode ?? '').trim();

    return SalesDocMetaVm(
      partyName: party,
      docNumberOrId: docNo,
      status: q.status.trim(),
      currencyCode: currency,
      total: q.total,
      date: q.date,
      expiryDate: q.expiryDate,
    );
  }

  static String _bestDocNumber(ZohoQuote q) {
    final acc = (q.accountNumber ?? '').trim();
    if (acc.isNotEmpty) return acc;

    final id = q.quoteId.trim();
    return id.isEmpty ? '-' : id;
  }

  static List<SalesDocLineVm> _buildLines(ZohoQuote q) {
    return q.lineItems
        .map(
          (li) => SalesDocLineVm(
            title: _lineTitle(li),
            subtitle: _lineSubtitle(li),
            qty: li.quantity,
            rate: li.rate,
          ),
        )
        .toList(growable: false);
  }

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
