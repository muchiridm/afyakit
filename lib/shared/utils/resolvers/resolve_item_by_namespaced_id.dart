//lib/shared/utils/resolve/resolve_item_by_namespaced_id.dart

import 'package:afyakit/features/inventory/items/models/items/base_inventory_item.dart';

BaseInventoryItem? resolveItemByNamespacedId(
  List<BaseInventoryItem> items,
  String namespacedId,
) {
  for (final item in items) {
    final namespaced = '${item.type.name}__${item.id}';
    if (namespaced == namespacedId) return item;
  }
  return null;
}
