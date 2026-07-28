// lib/features/retail/catalog/widgets/catalog_ui_bits.dart

import 'dart:math' as math;

import 'package:afyakit/features/retail/catalog/models/catalog_models.dart';
import 'package:flutter/material.dart';

/// Shared, lightweight UI pieces used across the Catalog screen and sheets:
/// - Search bar
/// - Loading skeletons
/// - Bottom-sheet header
///
/// Keep these dumb and reusable (no Riverpod, no service calls).

// ─────────────────────────────────────────────────────────────
// Search
// ─────────────────────────────────────────────────────────────

class SearchBarField extends StatelessWidget {
  const SearchBarField({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onChanged,
    this.focusNode,
    this.resultCount,
    this.showClear = false,
    this.onClear,
    this.helper,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onChanged;
  final int? resultCount;

  final bool showClear;
  final VoidCallback? onClear;
  final Widget? helper;

  void _submit(BuildContext context) {
    FocusScope.of(context).unfocus();
    onSubmit(controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final String? resultsLabel = resultCount == null
        ? null
        : '$resultCount result${resultCount == 1 ? '' : 's'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final bool compact = constraints.maxWidth < 560;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  elevation: 0.6,
                  borderRadius: BorderRadius.circular(16),
                  color: theme.colorScheme.surface,
                  clipBehavior: Clip.antiAlias,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _submit(context),
                    onChanged: onChanged,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search for any medicine or health product',
                      hintStyle: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.45),
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 22,
                        color: theme.colorScheme.onSurface.withOpacity(0.62),
                      ),
                      suffixIcon: showClear
                          ? IconButton(
                              tooltip: 'Clear search',
                              onPressed: onClear,
                              icon: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.62,
                                ),
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),

                if (helper != null) ...[const SizedBox(height: 8), helper!],

                const SizedBox(height: 14),

                Center(
                  child: FilledButton.icon(
                    onPressed: () => _submit(context),
                    icon: const Icon(Icons.search_rounded, size: 20),
                    label: const Text('Search'),
                    style: FilledButton.styleFrom(
                      minimumSize: Size(compact ? 132 : 150, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        if (resultsLabel != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              resultsLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.55),
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
    final cross = width < 560 ? 1 : (width < 980 ? 2 : 3);
    final items = math.max(6, cross * 4);
    final aspect = width < 560 ? 3.0 : 3.15;

    return GridView.builder(
      controller: scrollController,
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: items,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: aspect,
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
          0.28,
        );
        final hi = theme.colorScheme.surfaceContainerHighest.withOpacity(0.48);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Color.lerp(base, hi, t),
          ),
        );
      },
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

  static String _clean(String? s) {
    final t = (s ?? '').trim();
    if (t.isEmpty || t.toLowerCase() == 'null') return '';
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceText = priceFormatter(tile.bestSellPrice).trim();

    final manufacturer = _clean(tile.supplierManufacturer);
    final form = _clean(tile.form);
    final offers = tile.offerCount ?? 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.medication_outlined,
          size: 24,
          color: theme.colorScheme.onSurface.withOpacity(0.82),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${tile.brand} ${tile.strengthSig}'.trim(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              if (manufacturer.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  manufacturer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.66),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (form.isNotEmpty) _PillChip(label: form),
                  if (tile.bestPackCount != null)
                    _PillChip(label: 'Pack ${tile.bestPackCount}'),
                  if (offers > 0)
                    _SoftBadge('$offers offer${offers == 1 ? '' : 's'}'),
                ],
              ),
            ],
          ),
        ),
        if (priceText.isNotEmpty) ...[
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                priceText,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: priceColor,
                  height: 1.0,
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
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;

  const _PillChip({required this.label});

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

class _SoftBadge extends StatelessWidget {
  final String text;

  const _SoftBadge(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
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
