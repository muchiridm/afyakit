// lib/core/api/afyakit/routes/routes_inventory.dart

part of 'routes.dart';

extension AfyaKitInventoryRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // Item types
  // ─────────────────────────────────────────────

  Uri itemTypes() => _uri('inventory/items/types');

  Uri itemTypeById(String typeId) =>
      _uri('inventory/items/types/${_seg(typeId)}');

  // ─────────────────────────────────────────────
  // Inventory items
  // ─────────────────────────────────────────────

  Uri items({String? itemType}) => _uri(
    'inventory/items',
    query: {
      if (itemType != null && itemType.trim().isNotEmpty)
        'item_type': itemType.trim(),
    },
  );

  Uri itemById(String itemId) => _uri('inventory/items/${_seg(itemId)}');

  Uri restoreItem(String itemId) =>
      _uri('inventory/items/${_seg(itemId)}/restore');

  // ─────────────────────────────────────────────
  // Preferences
  // ─────────────────────────────────────────────

  Uri preferenceField(String itemType, String field) =>
      _uri('inventory/preferences/${_seg(itemType)}/${_seg(field)}');

  // ─────────────────────────────────────────────
  // Inventory locations
  // ─────────────────────────────────────────────

  Uri locations({String? locationType}) => _uri(
    'inventory/locations',
    query: {
      if (locationType != null && locationType.trim().isNotEmpty)
        'location_type': locationType.trim(),
    },
  );

  Uri locationById(String locationId) =>
      _uri('inventory/locations/${_seg(locationId)}');

  Uri restoreLocation(String locationId) =>
      _uri('inventory/locations/${_seg(locationId)}/restore');

  // Add to AfyaKitInventoryRoutes extension in routes_inventory.dart:
  Uri locationTypes() => _uri('inventory/locations/types');
  Uri locationTypeById(String typeId) =>
      _uri('inventory/locations/types/${_seg(typeId)}');
  Uri restoreLocationType(String typeId) =>
      _uri('inventory/locations/types/${_seg(typeId)}/restore');

  // ─────────────────────────────────────────────
  // Batches
  // ─────────────────────────────────────────────

  Uri batches({String? storeId}) => _uri(
    'inventory/batches',
    query: {
      if (storeId != null && storeId.trim().isNotEmpty)
        'store_id': storeId.trim(),
    },
  );

  Uri batchById(String batchId) => _uri('inventory/batches/${_seg(batchId)}');

  Uri restoreBatch(String batchId) =>
      _uri('inventory/batches/${_seg(batchId)}/restore');

  // ─────────────────────────────────────────────
  // Imports
  // ─────────────────────────────────────────────

  Uri importInventory({
    required String type,
    bool dryRun = true,
    bool persist = false,
  }) => _uri(
    'inventory/imports/inventory',
    query: {'type': type.trim(), 'dryRun': '$dryRun', 'persist': '$persist'},
  );

  Uri importInventoryRaw({
    required String type,
    bool dryRun = true,
    bool persist = false,
  }) => _uri(
    'inventory/imports/inventory-raw',
    query: {'type': type.trim(), 'dryRun': '$dryRun', 'persist': '$persist'},
  );

  Uri importTemplate(String typeId) =>
      _uri('inventory/imports/templates/${_seg(typeId)}');

  // ─────────────────────────────────────────────
  // Issues
  // ─────────────────────────────────────────────

  Uri issues() => _uri('inventory/issues');

  Uri issueById(String issueId) => _uri('inventory/issues/${_seg(issueId)}');

  Uri approveIssue(String issueId) =>
      _uri('inventory/issues/${_seg(issueId)}/approve');

  Uri rejectIssue(String issueId) =>
      _uri('inventory/issues/${_seg(issueId)}/reject');

  Uri cancelIssue(String issueId) =>
      _uri('inventory/issues/${_seg(issueId)}/cancel');

  Uri issueStock(String issueId) =>
      _uri('inventory/issues/${_seg(issueId)}/issue');

  Uri receiveIssue(String issueId) =>
      _uri('inventory/issues/${_seg(issueId)}/receive');

  // ─────────────────────────────────────────────
  // Deliveries
  // ─────────────────────────────────────────────

  Uri deliveries() => _uri('inventory/deliveries');

  Uri deliveryById(String deliveryId) =>
      _uri('inventory/deliveries/${_seg(deliveryId)}');

  Uri openDeliverySession() => _uri('inventory/deliveries/session/open');

  Uri ensureDeliverySession() => _uri('inventory/deliveries/session');

  Uri deliverySession(String deliveryId) =>
      _uri('inventory/deliveries/session/${_seg(deliveryId)}');

  Uri finalizeDeliverySession(String deliveryId) =>
      _uri('inventory/deliveries/session/${_seg(deliveryId)}/finalize');

  // Inventory sources (external stock origins; not stock-holding locations).
  Uri sources() => _uri('inventory/sources');

  Uri sourceById(String sourceId) =>
      _uri('inventory/sources/${_seg(sourceId)}');

  Uri restoreSource(String sourceId) =>
      _uri('inventory/sources/${_seg(sourceId)}/restore');
}
