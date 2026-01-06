import 'package:afyakit/features/inventory/items/models/items/base_inventory_item.dart';
import 'package:afyakit/features/inventory/items/services/inventory_repo_service.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final allInventoryMapProvider = FutureProvider<Map<String, BaseInventoryItem>>((
  ref,
) async {
  final repo = ref.read(inventoryRepoProvider);
  return await repo.fetchAllItemsAsMap(ref.read(tenantSlugProvider));
});
