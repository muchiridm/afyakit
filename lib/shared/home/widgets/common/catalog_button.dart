// lib/shared/home/widgets/common/catalog_button.dart

import 'package:afyakit/core/tenancy/models/feature_keys.dart';
import 'package:afyakit/core/tenancy/widgets/feature_gate.dart';
import 'package:afyakit/features/retail/catalog/widgets/screens/catalog_screen.dart';
import 'package:flutter/material.dart';

class CatalogButton extends StatelessWidget {
  const CatalogButton({super.key, this.compact = true});

  /// compact=true keeps it small; compact=false can be used elsewhere if needed
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FeatureGate(
      featureKey: FeatureKeys.retail,
      fallback: const SizedBox.shrink(),
      child: compact ? _CatalogChipButton() : _CatalogFullButton(),
    );
  }
}

class _CatalogChipButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.apps, size: 18),
      label: const Text('Catalog'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CatalogScreen()));
      },
    );
  }
}

class _CatalogFullButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.apps),
      label: const Text('Catalog'),
      onPressed: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CatalogScreen()));
      },
    );
  }
}
