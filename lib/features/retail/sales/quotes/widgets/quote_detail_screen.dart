// lib/features/retail/quotes/widgets/quote_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/shared/layout/app_page_scaffold.dart';

import 'package:afyakit/features/retail/sales/quotes/services/zoho_quotes_service.dart';
import 'package:afyakit/features/retail/sales/quotes/widgets/quote_editor_screen.dart';
import 'package:afyakit/features/retail/sales/quotes/widgets/quotes_list_screen.dart';

import 'package:afyakit/features/retail/sales/widgets/sales_doc_body.dart';
import 'package:afyakit/features/retail/sales/widgets/sales_doc_header.dart';

final _zohoDate = DateFormat('yyyy-MM-dd');

class QuoteDetailScreen extends ConsumerStatefulWidget {
  const QuoteDetailScreen({super.key, required this.quoteId});
  final String quoteId;

  @override
  ConsumerState<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends ConsumerState<QuoteDetailScreen> {
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
      // Saved or deleted => go back to list, clean stack.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const QuotesListScreen()),
        (_) => false,
      );
    }
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
      data: (svc) => FutureBuilder<Map<String, dynamic>>(
        future: svc.getQuote(widget.quoteId),
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

          final data = snap.data;
          if (data == null) {
            return _buildShell(
              context,
              title: 'Quote',
              body: const _ErrorState(
                title: 'Failed to load quote',
                message: 'No data returned',
              ),
            );
          }

          return _buildDetail(context, data);
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
    bool showEdit = false,
  }) {
    return AppPageScaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (showEdit)
            IconButton(
              tooltip: 'Edit quote',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editQuote(context),
            ),
        ],
      ),
      scrollable: false,
      body: body,
    );
  }

  // ─────────────────────────────────────────────
  // Detail UI (SalesDoc widgets)
  // ─────────────────────────────────────────────

  Widget _buildDetail(BuildContext context, Map<String, dynamic> q) {
    final parsed = _parse(q);

    final meta = SalesDocMetaVm(
      partyName: parsed.customer,
      docNumberOrId: parsed.quoteNumberOrId,
      status: parsed.status,
      currencyCode: parsed.currency,
      total: parsed.total,
      date: parsed.date,
    );

    final lines = parsed.lineItems
        .map(
          (li) => SalesDocLineVm(
            title: li.title, // may be '' (widgets can hide)
            subtitle: li.subtitle,
            qty: li.qty,
            rate: li.rate,
          ),
        )
        .toList(growable: false);

    return _buildShell(
      context,
      title: 'Quote',
      showEdit: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header (customer, status, number, date)
          SalesDocHeader(title: 'Quote', meta: meta),
          const Divider(height: 1),

          // Lines list
          Expanded(
            child: SalesDocLinesList(
              currencyCode: meta.currencyCode,
              lines: lines,
              mode: SalesDocMode.view,
            ),
          ),

          // Total bar
          SalesDocTotalBar(
            label: 'Total',
            total: meta.total,
            currencyCode: meta.currencyCode,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Parsing helpers
  // ─────────────────────────────────────────────

  _QuoteParsed _parse(Map<String, dynamic> q) {
    final customer = (q['customer_name'] ?? q['customerName'] ?? 'Customer')
        .toString()
        .trim();

    final status = (q['status'] ?? '').toString().trim();

    final currency = (q['currency_code'] ?? q['currencyCode'] ?? '')
        .toString()
        .trim();

    final total = _asNum(q['total']) ?? 0;

    final estimateNumber = (q['estimate_number'] ?? '').toString().trim();
    final estimateId = (q['estimate_id'] ?? q['id'] ?? widget.quoteId)
        .toString()
        .trim();
    final displayId = estimateNumber.isNotEmpty ? estimateNumber : estimateId;

    final dt = _parseZohoDate(
      q['date'] ?? q['estimate_date'] ?? q['quote_date'] ?? q['created_time'],
    );

    final items = <_LineItem>[];
    final raw = q['line_items'];

    if (raw is List) {
      for (final it in raw) {
        if (it is! Map) continue;
        final m = it.cast<String, dynamic>();

        final rawDesc = (m['description'] ?? '').toString();
        final rawName = (m['name'] ?? '').toString();

        final desc = _cleanZohoLineText(rawDesc);
        final name = _cleanZohoLineText(rawName);

        final title = desc.isNotEmpty ? desc : name;

        String? subtitle;
        if (desc.isNotEmpty && name.isNotEmpty && desc != name) {
          subtitle = name;
        }

        final qty = _asNum(m['quantity']) ?? 0;
        final rate = _asNum(m['rate']) ?? 0;

        items.add(
          _LineItem(title: title, subtitle: subtitle, qty: qty, rate: rate),
        );
      }
    }

    return _QuoteParsed(
      quoteNumberOrId: (displayId.isEmpty ? widget.quoteId : displayId),
      customer: (customer.isEmpty ? 'Customer' : customer),
      status: status,
      currency: currency,
      total: total,
      date: dt,
      lineItems: items,
    );
  }

  /// Treat Zoho placeholder "Item" as empty.
  static String _cleanZohoLineText(String v) {
    final t = v.trim();
    if (t.isEmpty) return '';
    if (t.toLowerCase() == 'item') return '';
    return t;
  }

  static DateTime? _parseZohoDate(Object? v) {
    if (v == null) return null;
    final s0 = v.toString().trim();
    if (s0.isEmpty) return null;

    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s0)) {
      final d = _zohoDate.parseStrict(s0);
      return DateTime(d.year, d.month, d.day);
    }

    // Fix timezone like +0300 -> +03:00
    final tzFix = RegExp(r'([+-]\d{2})(\d{2})$');
    final s = s0.replaceFirstMapped(tzFix, (m) => '${m[1]}:${m[2]}');

    final dt = DateTime.tryParse(s);
    return dt?.toLocal();
  }

  static num? _asNum(Object? v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim());
    return num.tryParse(v.toString());
  }
}

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

class _QuoteParsed {
  const _QuoteParsed({
    required this.quoteNumberOrId,
    required this.customer,
    required this.status,
    required this.currency,
    required this.total,
    required this.date,
    required this.lineItems,
  });

  final String quoteNumberOrId;
  final String customer;
  final String status;
  final String currency;
  final num total;
  final DateTime? date;
  final List<_LineItem> lineItems;
}

class _LineItem {
  const _LineItem({
    required this.title,
    this.subtitle,
    required this.qty,
    required this.rate,
  });

  final String title;
  final String? subtitle;
  final num qty;
  final num rate;
}
