import 'package:afyakit/core/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/core/inventory/services/inventory_repo_service.dart';
import 'package:afyakit/hq/tenants/v2/providers/tenant_slug_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final allInventoryMapProvider = FutureProvider<Map<String, BaseInventoryItem>>((
  ref,
) async {
  final repo = ref.read(inventoryRepoProvider);
  return await repo.fetchAllItemsAsMap(ref.read(tenantSlugProvider));
});
