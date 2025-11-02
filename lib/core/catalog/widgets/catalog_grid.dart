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
    final cross = width < 520 ? 1 : (width < 900 ? 2 : 3);

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
            childAspectRatio: 3.6,
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
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tile.brand} ${tile.strengthSig}'.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _PillChip(
                          label: tile.form.isEmpty ? 'form' : tile.form,
                          icon: Icons.category_outlined,
                        ),
                        // 🔻 removed offers badge
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (priceText.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      priceText,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16.5,
                        color: priceColor,
                      ),
                    ),
                    const SizedBox(height: 2),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14), const SizedBox(width: 6)],
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

// 🔻 removed _SoftBadge class completely

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
