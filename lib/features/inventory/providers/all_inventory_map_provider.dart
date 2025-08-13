import 'package:afyakit/features/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/features/inventory/providers/inventory_repo_provider.dart';
import 'package:afyakit/features/inventory/services/inventory_repo_service.dart';
import 'package:afyakit/shared/providers/tenant_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final allInventoryMapProvider = FutureProvider<Map<String, BaseInventoryItem>>((
  ref,
) async {
  final repo = ref.read(inventoryRepoProvider);
  return await repo.fetchAllItemsAsMap(ref.read(tenantIdProvider));
});
