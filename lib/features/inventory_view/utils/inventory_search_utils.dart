// File: lib/features/inventory_view/utils/inventory_search_utils.dart

import 'package:afyakit/features/inventory/models/items/base_inventory_item.dart';

bool matchesQuery(BaseInventoryItem item, String rawQuery) {
  final lowerQuery = rawQuery.trim().toLowerCase();
  if (lowerQuery.isEmpty) return true;

  return item.searchTerms.any(
    (term) => term?.toLowerCase().contains(lowerQuery) ?? false,
  );
}
