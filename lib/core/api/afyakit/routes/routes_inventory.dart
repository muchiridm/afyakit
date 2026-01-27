// lib/core/api/afyakit/routes/routes_inventory.dart

part of 'routes.dart';

extension AfyaKitInventoryRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 📦 Inventory (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  Uri inventory(String itemType) =>
      _uri('inventory', query: {'type': itemType});
  Uri createItem() => _uri('inventory');

  Uri itemById(String id, {String? type}) => _uri(
    'inventory/${_seg(id)}',
    query: (type != null && type.trim().isNotEmpty)
        ? {'type': type.trim()}
        : null,
  );

  // ─────────────────────────────────────────────
  // ⚙️ Preferences (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  Uri preferenceField(String itemType, String field) =>
      _uri('preferences/${_seg(itemType)}/${_seg(field)}');

  // ─────────────────────────────────────────────
  // 📍 Inventory Locations (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  Uri getTypedLocations(InventoryLocationType type) =>
      _uri('inventory-locations/${type.asString}');

  Uri addTypedLocation(InventoryLocationType type) =>
      _uri('inventory-locations/${type.asString}');

  Uri deleteTypedLocation(InventoryLocationType type, String id) =>
      _uri('inventory-locations/${type.asString}/${_seg(id)}');

  // ─────────────────────────────────────────────
  // 🧪 Batches (tenant-scoped; authenticated, per store)
  // ─────────────────────────────────────────────

  Uri listBatches(String storeId) => _uri('stores/${_seg(storeId)}/batches');
  Uri createBatch(String storeId) => _uri('stores/${_seg(storeId)}/batches');
  Uri updateBatch(String storeId, String batchId) =>
      _uri('stores/${_seg(storeId)}/batches/${_seg(batchId)}');
  Uri deleteBatch(String storeId, String batchId) =>
      _uri('stores/${_seg(storeId)}/batches/${_seg(batchId)}');

  // ─────────────────────────────────────────────
  // 📥 Imports (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  Uri importInventory({
    required String type,
    bool dryRun = true,
    bool persist = false,
  }) => _uri(
    'imports/inventory',
    query: {'type': type, 'dryRun': '$dryRun', 'persist': '$persist'},
  );

  Uri importInventoryRaw({
    required String type,
    bool dryRun = true,
    bool persist = false,
  }) => _uri(
    'imports/inventory-raw',
    query: {'type': type, 'dryRun': '$dryRun', 'persist': '$persist'},
  );

  Uri importTemplate(String type) => _uri('imports/templates/$type');
}
