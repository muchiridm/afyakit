// lib/core/catalog/widgets/catalog_components/catalog_ui_bits.dart

import 'dart:math' as math;

import 'package:afyakit/features/retail/catalog/catalog_models.dart';
import 'package:flutter/material.dart';

/// Shared, lightweight UI pieces used across the Catalog screen and sheets:
/// - Search bar
/// - Loading skeletons
/// - Error pane
/// - Bottom-sheet header
///
/// Keep these “dumb” and reusable (no Riverpod, no service calls).

// ─────────────────────────────────────────────────────────────
// Search
// ─────────────────────────────────────────────────────────────

// lib/core/catalog/widgets/catalog_components/catalog_ui_bits.dart
class SearchBarField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode; // ✅ NEW
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onChanged;
  final int? resultCount;

  const SearchBarField({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onChanged,
    this.focusNode, // ✅ NEW
    this.resultCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String? resultsLabel = (resultCount != null)
        ? '${resultCount!} result${resultCount == 1 ? '' : 's'}'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          elevation: 1.5,
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface,
          child: TextField(
            controller: controller,
            focusNode: focusNode, // ✅ NEW
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmit,
            onChanged: onChanged,
            decoration: const InputDecoration(
              hintText: 'Search brand, strength, form…',
              prefixIcon: Icon(Icons.search),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
          ),
        ),
        if (resultsLabel != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              resultsLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Loading skeletons
// ─────────────────────────────────────────────────────────────

class SkeletonGrid extends StatelessWidget {
  final ScrollController scrollController;

  const SkeletonGrid({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cross = width < 520 ? 1 : (width < 900 ? 2 : 3);
    final items = math.max(6, cross * 4);

    return GridView.builder(
      controller: scrollController,
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: items,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 3.6,
      ),
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _ac,
      builder: (_, __) {
        final t = (math.sin(_ac.value * 2 * math.pi) + 1) / 2;
        final base = theme.colorScheme.surfaceContainerHighest.withOpacity(
          0.35,
        );
        final hi = theme.colorScheme.surfaceContainerHighest.withOpacity(0.65);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Color.lerp(base, hi, t),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────

class ErrorPane extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const ErrorPane({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40),
          const SizedBox(height: 8),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Bottom sheet header (tile quick summary)
// ─────────────────────────────────────────────────────────────

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
