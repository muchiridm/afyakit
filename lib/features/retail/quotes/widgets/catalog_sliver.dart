// lib/features/retail/quotes/widgets/catalog_sliver.dart

import 'package:afyakit/features/retail/quotes/controllers/quote_editor_state.dart';
import 'package:flutter/material.dart';

import '../models/di_sales_tile.dart';

class CatalogSliver extends StatelessWidget {
  const CatalogSliver({
    super.key,
    required this.state,
    required this.onAdd,
    required this.onLoadMore,
    required this.onClearSearch,
    this.enabled = true,
  });

  final QuoteEditorState state;
  final void Function(DiSalesTile) onAdd;
  final VoidCallback onLoadMore;
  final VoidCallback onClearSearch;

  /// Disable add buttons in preview/read-only flows.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty && state.loadingCatalog) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.items.isEmpty) {
      final hasQuery = state.q.trim().isNotEmpty;
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyState(
          title: hasQuery ? 'No results' : 'Search the sales catalog',
          subtitle: hasQuery
              ? 'Try a different search.'
              : 'Type a drug name, strength, or brand.',
          actionLabel: hasQuery ? 'Clear search' : 'Browse',
          onAction: onClearSearch,
        ),
      );
    }

    return SliverList.separated(
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (state.hasMore && i == state.items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: state.loadingCatalog ? null : onLoadMore,
                icon: const Icon(Icons.expand_more),
                label: const Text('Load more'),
              ),
            ),
          );
        }

        final tile = state.items[i];
        return _CatalogTileRow(
          tile: tile,
          enabled: enabled,
          onAdd: () => onAdd(tile),
        );
      },
    );
  }
}

class _CatalogTileRow extends StatelessWidget {
  const _CatalogTileRow({
    required this.tile,
    required this.onAdd,
    required this.enabled,
  });

  final DiSalesTile tile;
  final VoidCallback onAdd;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final title = tile.tileTitle.trim().isEmpty
        ? 'Item'
        : tile.tileTitle.trim();

    final price = tile.bestSellPrice;
    final priceText = (price == null || price <= 0) ? '—' : price.toString();

    final meta = <String>[
      if ((tile.form ?? '').trim().isNotEmpty) tile.form!.trim(),
      if (tile.bestPackCount != null) 'Pack ${tile.bestPackCount}',
      'Offers ${tile.offerCount}',
      if ((tile.bestSupplier ?? '').trim().isNotEmpty)
        tile.bestSupplier!.trim(),
    ].take(2).join(' • ');

    final action = enabled
        ? FilledButton(onPressed: onAdd, child: const Text('Add'))
        : OutlinedButton(onPressed: null, child: const Text('Add'));

    return ListTile(
      title: Text(title),
      subtitle: meta.trim().isEmpty ? null : Text(meta),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 190),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                priceText,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            action,
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_long, size: 44),
              const SizedBox(height: 12),
              Text(title, style: t.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(subtitle, style: t.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
