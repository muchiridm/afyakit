// lib/core/catalog/widgets/_catalog_grid.dart

import 'package:afyakit/core/catalog/catalog_models.dart';
import 'package:flutter/material.dart';

class CatalogGrid extends StatelessWidget {
  final List<CatalogTile> items;
  final ScrollController scrollController;
  final void Function(CatalogTile) onTapTile;
  final bool showTailLoader;
  final String Function(num?) priceFormatter;
  final Color priceColor;

  const CatalogGrid({
    super.key,
    required this.items,
    required this.scrollController,
    required this.onTapTile,
    required this.showTailLoader,
    required this.priceFormatter,
    required this.priceColor,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // responsive columns
    final cross = width < 520 ? 1 : (width < 900 ? 2 : 3);

    // for 1-column, make it a bit taller so we don’t starve the row
    final aspect = width < 520 ? 3.25 : 3.6;

    return Column(
      children: [
        GridView.builder(
          controller: scrollController,
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: aspect,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _CatalogCard(
            tile: items[i],
            onTap: () => onTapTile(items[i]),
            priceFormatter: priceFormatter,
            priceColor: priceColor,
          ),
        ),
        if (showTailLoader) ...[
          const SizedBox(height: 12),
          const _TailLoader(),
        ],
      ],
    );
  }
}

class _CatalogCard extends StatelessWidget {
  final CatalogTile tile;
  final VoidCallback onTap;
  final String Function(num?) priceFormatter;
  final Color priceColor;

  const _CatalogCard({
    required this.tile,
    required this.onTap,
    required this.priceFormatter,
    required this.priceColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceText = priceFormatter(tile.bestSellPrice);

    return Material(
      elevation: 1.5,
      borderRadius: BorderRadius.circular(14),
      color: theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          // ⬇️ was 14,10,14,10 → shave 2px top/bottom
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // leading icon / thumb
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: theme.colorScheme.primaryContainer,
                ),
                child: const Icon(Icons.medication, size: 24),
              ),
              const SizedBox(width: 12),
              // middle: title + pill
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min, // 👈 keep it tight
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tile.brand} ${tile.strengthSig}'.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2), // ⬇️ was 3
                    Wrap(
                      spacing: 6,
                      runSpacing: 0,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _PillChip(
                          label: tile.form.isEmpty ? 'form' : tile.form,
                          icon: Icons.category_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // right: price
              if (priceText.isNotEmpty)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      priceText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: priceColor,
                      ),
                    ),
                    // ⬇️ was SizedBox(height: 1)
                    Text(
                      'KES',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.textTheme.labelSmall?.color?.withOpacity(
                          0.7,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _PillChip({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      // ⬇️ slimmer so it doesn’t push the row
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 2, // was 3
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13), const SizedBox(width: 5)],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TailLoader extends StatelessWidget {
  const _TailLoader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 18.0),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
