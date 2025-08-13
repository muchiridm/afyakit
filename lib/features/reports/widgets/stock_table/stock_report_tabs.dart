import 'package:afyakit/features/inventory/models/item_type_enum.dart';
import 'package:flutter/material.dart';

class StockReportTabs extends StatelessWidget {
  const StockReportTabs({
    super.key,
    required this.tabs,
    required this.onTabChanged,
  });

  final List<ItemType> tabs;
  final void Function(int index) onTabChanged;

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) return const SizedBox.shrink();

    return TabBar(
      isScrollable: tabs.length > 3,
      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
      indicatorColor: Theme.of(context).colorScheme.primary,
      labelColor: Theme.of(context).colorScheme.primary,
      unselectedLabelColor: Theme.of(context).disabledColor,
      onTap: onTabChanged,
      tabs: tabs.map((tab) => Tab(text: tab.label)).toList(),
    );
  }
}
