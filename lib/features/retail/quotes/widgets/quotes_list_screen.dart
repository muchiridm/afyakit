// lib/features/retail/quotes/widgets/quotes_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/state/paged_query_controller.dart';

import 'package:afyakit/features/retail/quotes/controllers/quotes_list_controller.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_editor_mode_x.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';
import 'package:afyakit/features/retail/quotes/widgets/quote_editor_screen.dart';
import 'package:intl/intl.dart';

class QuotesListScreen extends ConsumerWidget {
  const QuotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quotesListControllerProvider);
    final ctl = ref.read(quotesListControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotes'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: state.loading ? null : () => ctl.refresh(reset: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewQuote(context),
        icon: const Icon(Icons.add),
        label: const Text('New quote'),
      ),
      body: Column(
        children: [
          if (state.error != null) _buildError(context, state, ctl),
          Expanded(child: _buildBody(context, state, ctl)),
          if (state.loadingMore) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }

  void _openNewQuote(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const QuoteEditorScreen(mode: QuoteEditorMode.create),
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    PagedQueryState<ZohoQuote> state,
    QuotesListController ctl,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: _ErrorBanner(
        message: state.error!,
        onRetry: () => ctl.refresh(reset: true),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PagedQueryState<ZohoQuote> state,
    QuotesListController ctl,
  ) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.items.isEmpty) {
      return _empty(context, contextLabel: 'No quotes yet');
    }

    return RefreshIndicator(
      onRefresh: () => ctl.refresh(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (!state.hasMore) return false;

          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 240) {
            ctl.loadMore();
          }
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          itemCount: state.items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final q = state.items[i];
            return _QuoteCard(
              q: q,
              onPreview: () => _openQuotePreview(context, q.quoteId),
              onEdit: () => _openQuoteEdit(context, q.quoteId),
            );
          },
        ),
      ),
    );
  }

  void _openQuotePreview(BuildContext context, String quoteId) {
    final id = quoteId.trim();
    if (id.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            QuoteEditorScreen(quoteId: id, mode: QuoteEditorMode.preview),
      ),
    );
  }

  void _openQuoteEdit(BuildContext context, String quoteId) {
    final id = quoteId.trim();
    if (id.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            QuoteEditorScreen(quoteId: id, mode: QuoteEditorMode.edit),
      ),
    );
  }

  Widget _empty(BuildContext context, {required String contextLabel}) {
    final t = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long, size: 44),
              const SizedBox(height: 12),
              Text(
                contextLabel,
                style: t.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Tap “New quote” to create one.',
                style: t.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.q,
    required this.onPreview,
    required this.onEdit,
  });

  final ZohoQuote q;
  final VoidCallback onPreview;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final customer = q.customerName.trim().isEmpty
        ? 'Customer'
        : q.customerName.trim();

    final dateText = _formatDate(q.date);
    final ref = (q.referenceNumber ?? '').trim();

    final currency = (q.currencyCode ?? '').trim(); // <— adjust if different
    final amount = _formatMoney(q.total, currencyCode: currency);

    return Card(
      elevation: 0,
      color: scheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPreview,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LeadingIcon(status: q.status),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer,
                            style: t.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _StatusChip(status: q.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
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

              const SizedBox(width: 12),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amount,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ],
          ),
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
    // If you don’t want intl, remove it and just do: '$currencyCode $v'
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
        const SizedBox(width: 6),
        Text(text, style: t.bodySmall),
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
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            IconButton(
              tooltip: 'Retry',
              onPressed: onRetry,
              icon: Icon(Icons.refresh, color: scheme.onErrorContainer),
            ),
          ],
        ),
      ),
    );
  }
}
