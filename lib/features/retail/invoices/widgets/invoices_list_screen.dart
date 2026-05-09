// lib/features/retail/invoices/widgets/invoices_list_screen.dart

import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';
import 'package:afyakit/features/retail/shared/sales_doc/status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';
import 'package:afyakit/features/retail/invoices/controllers/invoices_list_controller.dart';
import 'package:afyakit/features/retail/invoices/zoho_invoice.dart';
import 'package:afyakit/features/retail/invoices/widgets/invoice_detail_screen.dart';

import 'package:afyakit/core/home/widgets/home_shell.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/state/paged_query_controller.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_tile.dart';

import 'package:afyakit/features/retail/shared/sales_doc/list_card.dart';

class InvoicesListScreen extends ConsumerWidget {
  const InvoicesListScreen({super.key, this.scope = RetailDocScope.all});

  final RetailDocScope scope;

  static const double _loadMoreThresholdPx = 240;

  /// Keep consistent with Quotes list.
  static const double _contentMaxW = 720;

  bool get _isMine => scope == RetailDocScope.mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prov = invoicesListControllerProvider(scope);

    final state = ref.watch(prov);
    final ctl = ref.read(prov.notifier);

    final title = _isMine ? 'My Invoices' : 'Invoices';

    return AppPage(
      scrollable: false,
      maxWidth: _contentMaxW,
      title: title,
      showBack: true,
      onBack: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeShell()),
          (_) => false,
        );
      },
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: state.loading ? null : () => ctl.refresh(reset: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
      fab: FloatingActionButton.extended(
        onPressed: () => _openCatalogToStartNewInvoice(context),
        icon: const Icon(Icons.add),
        label: const Text('New invoice'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (state.error != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppShape.gap12),
                  child: _ErrorBanner(
                    message: state.error!,
                    onRetry: () => ctl.refresh(reset: true),
                  ),
                ),
              ],
              Expanded(child: _buildBody(context, state, ctl)),
              if (state.loadingMore)
                const Padding(
                  padding: EdgeInsets.only(top: AppShape.gap8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          ),
          if (state.loading && state.items.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────

  void _openCatalogToStartNewInvoice(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CatalogScreen()));
  }

  void _openExistingInvoice(BuildContext context, ZohoInvoice inv) {
    final id = inv.invoiceId.trim();
    if (id.isEmpty) {
      _toast(context, 'Missing invoice id');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: id)),
    );
  }

  // ─────────────────────────────────────────────
  // Body
  // ─────────────────────────────────────────────

  Widget _buildBody(
    BuildContext context,
    PagedQueryState<ZohoInvoice> state,
    InvoicesListController ctl,
  ) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.items.isEmpty) {
      return _EmptyState(
        icon: Icons.receipt_outlined,
        title: 'No invoices yet',
        subtitle: _isMine
            ? 'Your invoices will appear here once they are issued.'
            : 'Tap “New invoice” to build one from the catalog.',
        actionLabel: _isMine ? 'Refresh' : 'New invoice',
        onAction: _isMine
            ? () => ctl.refresh(reset: true)
            : () => _openCatalogToStartNewInvoice(context),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ctl.refresh(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.maxScrollExtent <= 0) return false;
          if (!state.hasMore) return false;
          if (state.loadingMore || state.loading) return false;

          if (n.metrics.pixels >=
              n.metrics.maxScrollExtent - _loadMoreThresholdPx) {
            ctl.loadMore();
          }
          return false;
        },
        child: ListView(
          padding: const EdgeInsets.only(top: 0, bottom: 96),
          children: [
            SalesListCard(
              title: _isMine ? 'Your recent invoices' : 'Recent invoices',
              icon: Icons.receipt_outlined,
              children: [
                for (final inv in state.items)
                  _InvoiceRow(
                    inv: inv,
                    onOpen: () => _openExistingInvoice(context, inv),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.inv, required this.onOpen});

  final ZohoInvoice inv;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final customer = inv.customerName.trim().isEmpty
        ? 'Customer'
        : inv.customerName.trim();

    final dateText = _formatDate(inv.date);
    final ref = (inv.accountNumber ?? '').trim();

    final currency = (inv.currencyCode ?? '').trim();
    final amount = _formatMoney(inv.total, currencyCode: currency);

    return InkWell(
      onTap: onOpen,
      borderRadius: AppShape.tileRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SalesDocLeadingIcon(status: inv.status),
            const SizedBox(width: AppShape.gap12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          customer,
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppShape.gap10),
                      SalesDocStatusChip(status: inv.status),
                    ],
                  ),
                  const SizedBox(height: AppShape.gap6),
                  Wrap(
                    spacing: AppShape.gap10,
                    runSpacing: AppShape.gap6,
                    children: [
                      _MetaPill(
                        icon: Icons.calendar_today_outlined,
                        text: dateText,
                      ),
                      if (ref.isNotEmpty)
                        _MetaPill(icon: Icons.tag_outlined, text: ref),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppShape.gap12),
            Text(
              amount,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime? d) {
    if (d == null) return '—';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static String _formatMoney(num v, {required String currencyCode}) {
    final nf = NumberFormat.decimalPattern();
    final code = currencyCode.isEmpty ? 'Total' : currencyCode;
    return '$code ${nf.format(v)}';
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: AppShape.gap6),
        Text(
          text,
          style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppTile(
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 20),
          const SizedBox(width: AppShape.gap10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Retry',
            onPressed: onRetry,
            icon: Icon(Icons.refresh, color: scheme.error),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44),
              const SizedBox(height: AppShape.gap12),
              Text(title, style: t.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: AppShape.gap6),
              Text(subtitle, style: t.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: AppShape.gap16),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(
                  actionLabel == 'Refresh' ? Icons.refresh : Icons.add,
                ),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
