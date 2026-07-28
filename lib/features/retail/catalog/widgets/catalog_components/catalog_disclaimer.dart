// lib/features/retail/catalog/widgets/catalog_components/catalog_disclaimer.dart

import 'package:flutter/material.dart';

class CatalogDisclaimer extends StatelessWidget {
  const CatalogDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        'Prices may change without notice. '
        'Prescription medicines require a valid prescription.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
