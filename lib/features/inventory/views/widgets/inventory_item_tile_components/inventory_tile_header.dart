import 'package:flutter/material.dart';

class InventoryTileHeader extends StatelessWidget {
  final String genericName;
  final String subtitle;
  final int totalStock;
  final bool canEdit;
  final VoidCallback onEdit;

  const InventoryTileHeader({
    super.key,
    required this.genericName,
    required this.subtitle,
    required this.totalStock,
    required this.canEdit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              canEdit
                  ? GestureDetector(
                    onTap: onEdit,
                    child: Text(
                      genericName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                  : Text(
                    genericName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              if (subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
            ],
          ),
        ),
        Text(
          '$totalStock',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
      ],
    );
  }
}
