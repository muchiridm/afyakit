// lib/features/retail/catalog/widgets/catalog_components/catalog_disclaimer.dart

import 'package:flutter/material.dart';

class CatalogDisclaimer extends StatelessWidget {
  const CatalogDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Prices may change without notice. Prescription medicines require a valid prescription.',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.65),
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}
