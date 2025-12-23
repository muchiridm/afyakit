// 📁 inventory/widgets/inventory_search_bar.dart

import 'package:flutter/material.dart';

class StockSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sortAscending;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSortToggle;

  const StockSearchBar({
    super.key,
    required this.controller,
    required this.sortAscending,
    required this.onChanged,
    this.onSortToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: 'Search by group, generic or brand name...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (onSortToggle != null) // ✅ conditionally render icon button
            IconButton(
              icon: Icon(
                sortAscending ? Icons.arrow_downward : Icons.arrow_upward,
              ),
              tooltip: 'Toggle Sort',
              onPressed: onSortToggle,
            ),
        ],
      ),
    );
  }
}
