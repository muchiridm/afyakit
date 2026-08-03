// lib/features/retail/catalog/widgets/catalog_grid.dart

import 'package:afyakit/features/retail/catalog/models/catalog_models.dart';
import 'package:flutter/material.dart';

class CatalogGrid extends StatelessWidget {
  const CatalogGrid({
    super.key,
    required this.items,
    required this.scrollController,
    required this.onTapTile,
    required this.showTailLoader,
    required this.priceFormatter,
    required this.priceColor,
  });

  final List<CatalogTile> items;
  final ScrollController scrollController;
  final void Function(CatalogTile) onTapTile;
  final bool showTailLoader;
  final String Function(num?) priceFormatter;
  final Color priceColor;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;

    final int cross = width < 560 ? 1 : (width < 980 ? 2 : 3);

    // Slightly lower ratio = slightly taller cards.
    // Previous desktop/tablet ratio was tight enough to overflow by a few px.
    final double aspect = width < 560 ? 2.85 : 2.95;

    return Column(
      children: <Widget>[
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
          itemBuilder: (_, int i) {
            final CatalogTile item = items[i];

            return _CatalogCard(
              tile: item,
              onTap: () => onTapTile(item),
              priceFormatter: priceFormatter,
              priceColor: priceColor,
            );
          },
        ),
        if (showTailLoader) ...<Widget>[
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

  static String _clean(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) return '';
    if (text.toLowerCase() == 'null') return '';
    return text;
  }

  static String _clamp(String value, {int max = 42}) {
    final String text = value.trim();
    if (text.isEmpty) return text;
    if (text.length <= max) return text;
    return '${text.substring(0, max - 1)}…';
  }

  static String _joinMeta(String a, String b) {
    final String x = a.trim();
    final String y = b.trim();

    if (x.isEmpty && y.isEmpty) return '';
    if (x.isEmpty) return y;
    if (y.isEmpty) return x;

    return '$x • $y';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final String priceText = priceFormatter(tile.bestSellPrice).trim();

    final String brand = _clean(tile.brand);
    final String strength = _clean(tile.strengthSig);
    final String title = '$brand $strength'.trim();
    final String safeTitle = title.isEmpty ? 'Item' : title;

    final String manufacturer = _clean(tile.supplierManufacturer);
    final String desc = _clean(tile.tileDescWithWhoPath ?? tile.tileDesc);

    final String metaLine = _joinMeta(
      _clamp(manufacturer, max: 18),
      _clamp(desc, max: 48),
    );

    final TextStyle? titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 15,
      height: 1.05,
    );

    final TextStyle? metaStyle = theme.textTheme.bodySmall?.copyWith(
      height: 1.08,
      fontWeight: FontWeight.w500,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
    );

    return Material(
      elevation: 0.6,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: ClipRect(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        safeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      if (metaLine.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          metaLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: metaStyle,
                        ),
                      ],
                      const SizedBox(height: 6),
                      _ChipRow(tile: tile),
                    ],
                  ),
                ),
              ),
              if (priceText.isNotEmpty) ...<Widget>[
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 86),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        priceText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          height: 1.0,
                          color: priceColor,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'KES',
                        style: theme.textTheme.labelSmall?.copyWith(
                          height: 1.0,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.56,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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
    final List<Widget> chips = <Widget>[];

    final String atc = tile.whoAtcCode?.trim() ?? '';
    if (atc.isNotEmpty) {
      chips.add(_PillChip(label: 'ATC $atc', emphasize: true));
    }

    final String form = tile.form.trim();
    if (form.isNotEmpty) {
      chips.add(_PillChip(label: form));
    }

    if (tile.bestPackCount != null) {
      chips.add(_PillChip(label: 'Pack ${tile.bestPackCount}'));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    // Keeps the tile compact. If there are too many chips, they are clipped
    // instead of pushing the card taller and causing RenderFlex overflow.
    return SizedBox(
      height: 24,
      child: ClipRect(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            children: chips
                .map(
                  (Widget chip) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: chip,
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({required this.label, this.emphasize = false});

  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Color background = emphasize
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.7)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42);

    final Color foreground = emphasize
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface.withValues(alpha: 0.76);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: background,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          height: 1.0,
          fontWeight: FontWeight.w600,
          color: foreground,
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
