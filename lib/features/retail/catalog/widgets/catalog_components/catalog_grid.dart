// lib/core/catalog/widgets/catalog_components/catalog_grid.dart

import 'package:afyakit/features/retail/catalog/catalog_models.dart';
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

    // ✅ Make cards a bit taller (more breathing room).
    // Lower ratio => taller tiles.
    final aspect = width < 520 ? 2.55 : 2.7;

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

  // -------------------------
  // Text safety helpers
  // -------------------------

  static String _clean(String? s) {
    final t = (s ?? '').trim();
    if (t.isEmpty) return '';
    if (t.toLowerCase() == 'null') return '';
    return t;
  }

  static String _clamp(String s, {int max = 36}) {
    final t = s.trim();
    if (t.isEmpty) return t;
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }

  static String _joinMeta(String mfg, String desc) {
    final a = mfg.trim();
    final b = desc.trim();
    if (a.isEmpty && b.isEmpty) return '';
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return '$a • $b';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceText = priceFormatter(tile.bestSellPrice).trim();

    final brand = _clean(tile.brand);
    final strength = _clean(tile.strengthSig);
    final title = '$brand $strength'.trim();
    final safeTitle = title.isEmpty ? 'Item' : title;

    final mfg = _clean(tile.supplierManufacturer);
    final desc = _clean(tile.tileDesc);

    // ✅ one-line meta (manufacturer + description), both truncated safely
    final metaLine = _joinMeta(_clamp(mfg, max: 26), _clamp(desc, max: 40));

    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: 14,
      height: 1.05,
    );

    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      height: 1.05,
      fontWeight: FontWeight.w600,
      color: theme.textTheme.bodySmall?.color?.withOpacity(0.72),
    );

    return Material(
      elevation: 1.5,
      borderRadius: BorderRadius.circular(14),
      color: theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
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

              // middle: title + meta + chips
              Expanded(
                child: ClipRect(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // title (1 line)
                      Text(
                        safeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: titleStyle,
                      ),
                      const SizedBox(height: 4),

                      // ✅ Meta line (1 line max)
                      if (metaLine.isNotEmpty)
                        Text(
                          metaLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: metaStyle,
                        )
                      else
                        const SizedBox(height: 0),

                      const SizedBox(height: 6),

                      // ✅ Chips line (clamped + cannot force height)
                      SizedBox(
                        height:
                            22, // <- hard clamp: no more RenderFlex overflow
                        child: _SingleLineChips(tile: tile),
                      ),
                    ],
                  ),
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
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        height: 1.05,
                        color: priceColor,
                      ),
                    ),
                    Text(
                      'KES',
                      style: theme.textTheme.labelSmall?.copyWith(
                        height: 1.05,
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

/// One-line, horizontally scrollable chips:
/// - labels are clamped so a single chip can't become absurdly long
/// - wrapped in ClipRect so it cannot request extra height
class _SingleLineChips extends StatelessWidget {
  const _SingleLineChips({required this.tile});
  final CatalogTile tile;

  static String _clamp(String s, {int max = 20}) {
    final t = s.trim();
    if (t.isEmpty) return t;
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }

  @override
  Widget build(BuildContext context) {
    final form = (tile.form).trim();
    final mfg = (tile.supplierManufacturer ?? '').trim();

    final chips = <Widget>[
      _PillChip(
        label: form.isEmpty ? 'Form' : 'Form ${_clamp(form, max: 12)}',
        icon: Icons.category_outlined,
      ),
      if (tile.bestPackCount != null)
        _PillChip(
          label: 'Pack ${tile.bestPackCount}',
          icon: Icons.inventory_2_outlined,
        ),
      if ((tile.volumeSig ?? '').trim().isNotEmpty)
        _PillChip(
          label: 'Vol ${_clamp(tile.volumeSig!.trim(), max: 10)}',
          icon: Icons.water_drop_outlined,
        ),
      if ((tile.concentrationSig ?? '').trim().isNotEmpty)
        _PillChip(
          label: 'Conc ${_clamp(tile.concentrationSig!.trim(), max: 10)}',
          icon: Icons.science_outlined,
        ),
      if (mfg.isNotEmpty)
        _PillChip(label: _clamp(mfg, max: 16), icon: Icons.factory_outlined),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return ClipRect(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              for (var i = 0; i < chips.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                chips[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

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
            softWrap: false,
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 12,
              height: 1.05,
            ),
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
