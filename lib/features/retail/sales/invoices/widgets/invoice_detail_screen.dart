import 'package:afyakit/core/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth_user/providers/current_user_providers.dart';
import 'package:afyakit/features/retail/sales/invoices/services/zoho_invoices_service.dart';
import 'package:afyakit/features/retail/sales/invoices/widgets/invoice_editor_screen.dart';
import 'package:afyakit/features/retail/sales/invoices/widgets/invoice_list_screen.dart';
import 'package:afyakit/features/retail/sales/widgets/sales_doc_body.dart';
import 'package:afyakit/features/retail/sales/widgets/sales_doc_header.dart';
import 'package:afyakit/shared/layout/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final _zohoDate = DateFormat('yyyy-MM-dd');

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  // ─────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────

  Future<void> _editInvoice(BuildContext context) async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null || !me.canManageInvoices) {
      _toast(context, 'Not allowed');
      return;
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InvoiceEditorScreen(editingInvoiceId: widget.invoiceId),
      ),
    );

    if (!context.mounted) return;

    if (changed == true) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const InvoicesListScreen()),
        (_) => false,
      );
    }
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final canEdit = me?.canManageInvoices ?? false;

    final svcAsync = ref.watch(zohoInvoicesServiceProvider);

    return svcAsync.when(
      loading: () => _buildShell(
        context,
        title: 'Invoice',
        body: const Center(child: CircularProgressIndicator()),
        showEdit: false,
      ),
      error: (e, _) => _buildShell(
        context,
        title: 'Invoice',
        body: _ErrorState(title: 'Zoho service failed', message: '$e'),
        showEdit: false,
      ),
      data: (svc) => FutureBuilder<Map<String, dynamic>>(
        future: svc.getInvoice(widget.invoiceId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _buildShell(
              context,
              title: 'Invoice',
              body: const Center(child: CircularProgressIndicator()),
              showEdit: false,
            );
          }

          if (snap.hasError) {
            return _buildShell(
              context,
              title: 'Invoice',
              body: _ErrorState(
                title: 'Failed to load invoice',
                message: '${snap.error ?? 'Unknown error'}',
              ),
              showEdit: false,
            );
          }

          final data = snap.data;
          if (data == null) {
            return _buildShell(
              context,
              title: 'Invoice',
              body: const _ErrorState(
                title: 'Failed to load invoice',
                message: 'No data returned',
              ),
              showEdit: false,
            );
          }

          return _buildDetail(context, data, canEdit: canEdit);
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
    required bool showEdit,
  }) {
    return AppPageScaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (showEdit)
            IconButton(
              tooltip: 'Edit invoice',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editInvoice(context),
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

  Widget _buildDetail(
    BuildContext context,
    Map<String, dynamic> inv, {
    required bool canEdit,
  }) {
    final parsed = _parse(inv);

    final meta = SalesDocMetaVm(
      partyName: parsed.customer,
      docNumberOrId: parsed.invoiceNumberOrId,
      status: parsed.status,
      currencyCode: parsed.currency,
      total: parsed.total,
      date: parsed.date,
    );

    final lines = parsed.lineItems
        .map(
          (li) => SalesDocLineVm(
            title: li.title,
            subtitle: li.subtitle,
            qty: li.qty,
            rate: li.rate,
          ),
        )
        .toList(growable: false);

    return _buildShell(
      context,
      title: 'Invoice',
      showEdit: canEdit,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SalesDocHeader(title: 'Invoice', meta: meta),
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

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─────────────────────────────────────────────
  // Parsing helpers
  // ─────────────────────────────────────────────

  _InvoiceParsed _parse(Map<String, dynamic> inv) {
    final customer = (inv['customer_name'] ?? inv['customerName'] ?? 'Customer')
        .toString()
        .trim();

    final status = (inv['status'] ?? '').toString().trim();

    final currency = (inv['currency_code'] ?? inv['currencyCode'] ?? '')
        .toString()
        .trim();

    final total = _asNum(inv['total']) ?? 0;

    final invoiceNumber = (inv['invoice_number'] ?? '').toString().trim();
    final invoiceId = (inv['invoice_id'] ?? inv['id'] ?? widget.invoiceId)
        .toString()
        .trim();
    final displayId = invoiceNumber.isNotEmpty ? invoiceNumber : invoiceId;

    final dt = _parseZohoDate(
      inv['date'] ?? inv['invoice_date'] ?? inv['created_time'],
    );

    final items = <_LineItem>[];
    final raw = inv['line_items'];

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

    return _InvoiceParsed(
      invoiceNumberOrId: (displayId.isEmpty ? widget.invoiceId : displayId),
      customer: (customer.isEmpty ? 'Customer' : customer),
      status: status,
      currency: currency,
      total: total,
      date: dt,
      lineItems: items,
    );
  }

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

class _InvoiceParsed {
  const _InvoiceParsed({
    required this.invoiceNumberOrId,
    required this.customer,
    required this.status,
    required this.currency,
    required this.total,
    required this.date,
    required this.lineItems,
  });

  final String invoiceNumberOrId;
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
