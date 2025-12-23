// lib/core/catalog/widgets/catalog_components/skeletons.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

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
