// lib/features/retail/sales/shared/widgets/sales_list_card.dart

import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_card.dart';
import 'package:afyakit/shared/widgets/app_tile.dart';
import 'package:flutter/material.dart';

class SalesListCard extends StatelessWidget {
  const SalesListCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: title,
      icon: icon,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            AppTile(child: children[i]),
            if (i != children.length - 1)
              const SizedBox(height: AppShape.gap10),
          ],
        ],
      ),
    );
  }
}
