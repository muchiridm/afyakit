// lib/shared/widgets/home_screens/common/catalog_button.dart

import 'package:afyakit/core/tenancy/models/feature_keys.dart';
import 'package:afyakit/core/tenancy/widgets/feature_gate.dart';
import 'package:afyakit/features/retail/catalog/widgets/screens/catalog_screen.dart';
import 'package:flutter/material.dart';

class CatalogButton extends StatelessWidget {
  const CatalogButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FeatureGate(
      featureKey: FeatureKeys.retail,
      fallback: const SizedBox.shrink(),
      child: IconButton(
        tooltip: 'Catalog',
        icon: const Icon(Icons.apps),
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CatalogScreen()));
        },
      ),
    );
  }
}
