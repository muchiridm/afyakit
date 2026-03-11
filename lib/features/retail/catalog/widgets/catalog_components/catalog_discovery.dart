// lib/features/retail/catalog/widgets/catalog_components/catalog_discovery.dart

import 'package:flutter/material.dart';

class CatalogDiscovery extends StatelessWidget {
  const CatalogDiscovery({super.key, this.onExampleTap});

  final ValueChanged<String>? onExampleTap;

  static const _examples = <String>[
    'Paracetamol',
    'Amoxicillin',
    'Cough syrup',
    'Eye drops',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withOpacity(0.64);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
          child: Column(
            children: [
              Text(
                'Search medicines, brands, or dosage forms',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Start typing above or refine the catalog using the filters.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Try searching for',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: _examples
                        .map((label) {
                          return _QuickHintChip(
                            label,
                            onTap: onExampleTap == null
                                ? null
                                : () => onExampleTap!(label),
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickHintChip extends StatelessWidget {
  const _QuickHintChip(this.label, {this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.74),
          fontWeight: FontWeight.w500,
        ),
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: child,
      ),
    );
  }
}
