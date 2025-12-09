// lib/core/catalog/widgets/catalog_components/catalog_grid.dart

import 'package:afyakit/modules/retail/catalog/catalog_models.dart';
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

    // slightly lower aspect ratio → more vertical space per tile
    final aspect = width < 520 ? 3.0 : 3.2;

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

  bool get _hasDesc =>
      tile.tileDesc != null && tile.tileDesc!.trim().isNotEmpty;

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
          // slightly tighter vertical padding to avoid grid overflow
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // leading icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: theme.colorScheme.primaryContainer,
                ),
                child: const Icon(Icons.medication, size: 20),
              ),
              const SizedBox(width: 10),
              // middle: title + (desc) + chips
              Expanded(
                child: Column(
                  // fill available height and compress children as needed
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // title
                    Text(
                      '${tile.brand} ${tile.strengthSig}'.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),

                    // description (1 line)
                    if (_hasDesc) ...[
                      const SizedBox(height: 2),
                      Text(
                        tile.tileDesc!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.1,
                          color: theme.textTheme.bodySmall?.color?.withOpacity(
                            0.7,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 4),

                    // single-line, horizontally scrollable chips
                    _SingleLineChips(tile: tile),
                  ],
                ),
              ),
              const SizedBox(width: 10),
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
                        fontSize: 15,
                        color: priceColor,
                      ),
                    ),
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

class _SingleLineChips extends StatelessWidget {
  final CatalogTile tile;

  const _SingleLineChips({required this.tile});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _PillChip(
        label: tile.form.isEmpty ? 'Form' : 'Form ${tile.form}',
        icon: Icons.category_outlined,
      ),
      if (tile.bestPackCount != null)
        _PillChip(
          label: 'Pack ${tile.bestPackCount}',
          icon: Icons.inventory_2_outlined,
        ),
      if (tile.volumeSig != null && tile.volumeSig!.trim().isNotEmpty)
        _PillChip(
          label: 'Vol ${tile.volumeSig}',
          icon: Icons.water_drop_outlined,
        ),
      if (tile.concentrationSig != null &&
          tile.concentrationSig!.trim().isNotEmpty)
        _PillChip(
          label: 'Conc ${tile.concentrationSig}',
          icon: Icons.science_outlined,
        ),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            chips[i],
          ],
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
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
