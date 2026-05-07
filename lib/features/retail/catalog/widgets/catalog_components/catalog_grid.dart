// lib/core/catalog/widgets/catalog_components/catalog_grid.dart

import 'package:afyakit/features/retail/catalog/models/catalog_models.dart';
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
    final cross = width < 560 ? 1 : (width < 980 ? 2 : 3);
    final aspect = width < 560 ? 3.0 : 3.15;

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
  const _CatalogCard({
    required this.tile,
    required this.onTap,
    required this.priceFormatter,
    required this.priceColor,
  });

  final CatalogTile tile;
  final VoidCallback onTap;
  final String Function(num?) priceFormatter;
  final Color priceColor;

  static String _clean(String? s) {
    final t = (s ?? '').trim();
    if (t.isEmpty) return '';
    if (t.toLowerCase() == 'null') return '';
    return t;
  }

  static String _clamp(String s, {int max = 42}) {
    final t = s.trim();
    if (t.isEmpty) return t;
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }

  static String _joinMeta(String a, String b) {
    final x = a.trim();
    final y = b.trim();
    if (x.isEmpty && y.isEmpty) return '';
    if (x.isEmpty) return y;
    if (y.isEmpty) return x;
    return '$x • $y';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceText = priceFormatter(tile.bestSellPrice).trim();

    final brand = _clean(tile.brand);
    final strength = _clean(tile.strengthSig);
    final title = '$brand $strength'.trim();
    final safeTitle = title.isEmpty ? 'Item' : title;

    final manufacturer = _clean(tile.supplierManufacturer);
    final desc = _clean(tile.tileDesc);
    final metaLine = _joinMeta(
      _clamp(manufacturer, max: 18),
      _clamp(desc, max: 34),
    );

    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 15,
      height: 1.08,
    );

    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      height: 1.15,
      fontWeight: FontWeight.w500,
      color: theme.colorScheme.onSurface.withOpacity(0.66),
    );

    return Material(
      elevation: 0.6,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      safeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                    if (metaLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        metaLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: metaStyle,
                      ),
                    ],
                    const SizedBox(height: 8),
                    _ChipRow(tile: tile),
                  ],
                ),
              ),
              if (priceText.isNotEmpty) ...[
                const SizedBox(width: 14),
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      priceText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        height: 1.0,
                        color: priceColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'KES',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.56),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.tile});

  final CatalogTile tile;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    final form = tile.form.trim();
    if (form.isNotEmpty) {
      chips.add(_PillChip(label: form));
    }

    if (tile.bestPackCount != null) {
      chips.add(_PillChip(label: 'Pack ${tile.bestPackCount}'));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.42),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withOpacity(0.76),
        ),
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
