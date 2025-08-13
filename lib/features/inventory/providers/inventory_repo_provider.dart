import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/inventory/services/inventory_repo_service.dart';

final inventoryRepoProvider = Provider<InventoryRepoService>((ref) {
  return InventoryRepoService();
});
