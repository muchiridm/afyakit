// lib/core/catalog/public/widgets/_sheet_header.dart
import 'package:afyakit/core/catalog/catalog_models.dart';
import 'package:flutter/material.dart';

class SheetHeader extends StatelessWidget {
  final CatalogTile tile;
  final String Function(num?) priceFormatter;
  final Color priceColor;
  const SheetHeader({
    super.key,
    required this.tile,
    required this.priceFormatter,
    required this.priceColor,
  });

  @override
  Widget build(BuildContext context) {
    final priceText = priceFormatter(tile.bestSellPrice);
    return Row(
      children: [
        const Icon(Icons.medication, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${tile.brand} ${tile.strengthSig}'.trim(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  _PillChip(
                    label: tile.form.isEmpty ? 'form' : tile.form,
                    icon: Icons.category_outlined,
                  ),
                  if ((tile.offerCount ?? 0) > 0)
                    _SoftBadge('${tile.offerCount} offers'),
                ],
              ),
            ],
          ),
        ),
        if (priceText.isNotEmpty)
          Text(
            priceText,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: priceColor,
            ),
          ),
      ],
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

class _SoftBadge extends StatelessWidget {
  final String text;
  const _SoftBadge(this.text);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
