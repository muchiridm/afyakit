import 'package:afyakit/shared/home/widgets/tenant_home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page_scaffold.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_card.dart';
import 'package:afyakit/shared/widgets/app_tile.dart';

import 'package:afyakit/shared/state/paged_query_controller.dart';

import 'package:afyakit/features/retail/sales/quotes/controllers/quotes_list_controller.dart';
import 'package:afyakit/features/retail/sales/quotes/models/zoho_quote.dart';

import 'package:afyakit/features/retail/sales/quotes/widgets/quote_detail_screen.dart';
import 'package:afyakit/features/retail/sales/quotes/widgets/quote_editor_screen.dart';

import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart'
    show CatalogScreen;

class QuotesListScreen extends ConsumerWidget {
  const QuotesListScreen({super.key});

  static const double _loadMoreThresholdPx = 240;

  /// This is the “Home-like card column” width.
  /// - Keep <= AppLayout.pageMaxW
  /// - Tune as you like (720 feels nice for sales lists).
  static const double _contentMaxW = 720;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quotesListControllerProvider);
    final ctl = ref.read(quotesListControllerProvider.notifier);

    return AppPageScaffold(
      appBar: _buildAppBar(context, state, ctl),
      fab: _buildFab(context),
      scrollable: false,
      body: Stack(
        children: [
          Column(
            children: [
              if (state.error != null) ...[
                _centeredContent(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppShape.gap12),
                    child: _ErrorBanner(
                      message: state.error!,
                      onRetry: () => ctl.refresh(reset: true),
                    ),
                  ),
                ),
              ],

              Expanded(child: _buildBody(context, ref, state, ctl)),

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
  // App bar / layout
  // ─────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    PagedQueryState<ZohoQuote> state,
    QuotesListController ctl,
  ) {
    return AppBar(
      leading: IconButton(
        tooltip: 'Home',
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const TenantHomeShell()),
            (_) => false,
          );
        },
      ),
      title: const Text('Quotes'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: state.loading ? null : () => ctl.refresh(reset: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _openCatalogToStartNewQuote(context),
      icon: const Icon(Icons.add),
      label: const Text('New quote'),
    );
  }

  // ─────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────

  void _openCatalogToStartNewQuote(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CatalogScreen()));
  }

  void _openExistingQuote(BuildContext context, ZohoQuote q) {
    final id = (q.quoteId).trim();
    if (id.isEmpty) {
      _toast(context, 'Missing quote id');
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => QuoteDetailScreen(quoteId: id)));
  }

  Future<void> _editQuote(
    BuildContext context,
    WidgetRef ref,
    ZohoQuote q,
  ) async {
    final id = (q.quoteId).trim();
    if (id.isEmpty) {
      _toast(context, 'Missing quote id');
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => QuoteEditorScreen(editingQuoteId: id)),
    );

    // Defensive refresh
    ref.read(quotesListControllerProvider.notifier).refresh(reset: true);
  }

  // ─────────────────────────────────────────────
  // Body
  // ─────────────────────────────────────────────

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    PagedQueryState<ZohoQuote> state,
    QuotesListController ctl,
  ) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.items.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: () => ctl.refresh(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          // Only consider scroll updates that are at/near the bottom.
          if (n.metrics.maxScrollExtent <= 0) return false;
          if (!state.hasMore) return false;
          if (state.loadingMore || state.loading) return false;

          if (n.metrics.pixels >=
              n.metrics.maxScrollExtent - _loadMoreThresholdPx) {
            ctl.loadMore();
          }
          return false;
        },
        child: _centeredContent(
          child: ListView(
            // AppPageScaffold already applies page padding.
            // We add only inner vertical rhythm + bottom space for FAB.
            padding: const EdgeInsets.only(top: 0, bottom: 96),
            children: [
              AppCard(
                title: 'Recent quotes',
                icon: Icons.receipt_long_outlined,
                child: Column(
                  children: [
                    for (int j = 0; j < state.items.length; j++) ...[
                      AppTile(
                        child: _QuoteRow(
                          q: state.items[j],
                          onOpen: () =>
                              _openExistingQuote(context, state.items[j]),
                          onEdit: () =>
                              _editQuote(context, ref, state.items[j]),
                        ),
                      ),
                      if (j != state.items.length - 1)
                        const SizedBox(height: AppShape.gap10),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return _centeredContent(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long, size: 44),
                const SizedBox(height: AppShape.gap12),
                Text(
                  'No quotes yet',
                  style: t.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppShape.gap6),
                Text(
                  'Tap “New quote” to build one from the catalog.',
                  style: t.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppShape.gap16),
                FilledButton.icon(
                  onPressed: () => _openCatalogToStartNewQuote(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New quote'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  Widget _centeredContent({required Widget child}) {
    return LayoutBuilder(
      builder: (context, c) {
        final cap = _contentMaxW <= AppLayout.pageMaxW
            ? _contentMaxW
            : AppLayout.pageMaxW;
        final w = AppLayout.clampWidth(c.maxWidth, cap);

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: w, child: child),
        );
      },
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ─────────────────────────────────────────────
// Row widgets (pure UI) — built to sit inside AppTile
// ─────────────────────────────────────────────

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({
    required this.q,
    required this.onOpen,
    required this.onEdit,
  });

  final ZohoQuote q;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final customer = q.customerName.trim().isEmpty
        ? 'Customer'
        : q.customerName.trim();
    final dateText = _formatDate(q.date);
    final ref = (q.referenceNumber ?? '').trim();

    final currency = (q.currencyCode ?? '').trim();
    final amount = _formatMoney(q.total, currencyCode: currency);

    return InkWell(
      onTap: onOpen,
      borderRadius: AppShape.tileRadius,
      child: Padding(
        // AppTile already pads; this keeps “list-row density” without feeling cramped.
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LeadingIcon(status: q.status),
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
                      _StatusChip(status: q.status),
                      const SizedBox(width: AppShape.gap6),
                      IconButton(
                        tooltip: 'Edit quote',
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
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

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.trim().toLowerCase();
    final icon = s.contains('sent')
        ? Icons.send_outlined
        : s.contains('draft')
        ? Icons.edit_note_outlined
        : Icons.receipt_long_outlined;

    return CircleAvatar(radius: 18, child: Icon(icon, size: 18));
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.trim();
    final label = s.isEmpty ? 'unknown' : s;
    return Chip(visualDensity: VisualDensity.compact, label: Text(label));
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
