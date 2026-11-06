// lib/core/api/afyakit/routes/routes_inventory.dart

part of 'routes.dart';

extension AfyaKitInventoryRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // Item types
  // ─────────────────────────────────────────────

  Uri itemTypes() => _uri('inventory/items/types');

  /// PATCH or DELETE only. There is no GET /items/types/:typeId.
  Uri itemTypeById(String typeId) =>
      _uri('inventory/items/types/${_seg(typeId)}');

  Uri updateItemType(String typeId) => itemTypeById(typeId);
  Uri archiveItemType(String typeId) => itemTypeById(typeId);

  // ─────────────────────────────────────────────
  // Inventory items
  // ─────────────────────────────────────────────

  Uri items({
    String? itemType,
    bool? includeArchived,
    int? page,
    int? perPage,
  }) => _uri(
    'inventory/items',
    query: {
      if (itemType != null && itemType.trim().isNotEmpty)
        'item_type': itemType.trim(),
      if (includeArchived != null) 'include_archived': '$includeArchived',
      if (page != null) 'page': '$page',
      if (perPage != null) 'per_page': '$perPage',
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

  Uri locations({
    String? locationType,
    bool? includeArchived,
    int? page,
    int? perPage,
  }) => _uri(
    'inventory/locations',
    query: {
      if (locationType != null && locationType.trim().isNotEmpty)
        'location_type': locationType.trim(),
      if (includeArchived != null) 'include_archived': '$includeArchived',
      if (page != null) 'page': '$page',
      if (perPage != null) 'per_page': '$perPage',
    },
  );

  Uri locationById(String locationId) =>
      _uri('inventory/locations/${_seg(locationId)}');

  Uri restoreLocation(String locationId) =>
      _uri('inventory/locations/${_seg(locationId)}/restore');

  Uri locationTypes() => _uri('inventory/locations/types');

  /// PATCH or DELETE only. There is no GET /locations/types/:typeId.
  Uri locationTypeById(String typeId) =>
      _uri('inventory/locations/types/${_seg(typeId)}');

  Uri updateLocationType(String typeId) => locationTypeById(typeId);
  Uri deactivateLocationType(String typeId) => locationTypeById(typeId);
  Uri restoreLocationType(String typeId) =>
      _uri('inventory/locations/types/${_seg(typeId)}/restore');

  // ─────────────────────────────────────────────
  // Batches
  // ─────────────────────────────────────────────

  Uri batches({
    String? storeId,
    String? itemId,
    String? itemType,
    bool? includeArchived,
    int? page,
    int? perPage,
  }) => _uri(
    'inventory/batches',
    query: {
      if (storeId != null && storeId.trim().isNotEmpty)
        'store_id': storeId.trim(),
      if (itemId != null && itemId.trim().isNotEmpty) 'item_id': itemId.trim(),
      if (itemType != null && itemType.trim().isNotEmpty)
        'item_type': itemType.trim(),
      if (includeArchived != null) 'include_archived': '$includeArchived',
      if (page != null) 'page': '$page',
      if (perPage != null) 'per_page': '$perPage',
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

  /// POST raw binary upload; caller must send X-Filename.
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

  Uri deliveries({int? page, int? perPage}) => _uri(
    'inventory/deliveries',
    query: {
      if (page != null) 'page': '$page',
      if (perPage != null) 'per_page': '$perPage',
    },
  );

  Uri deliveryById(String deliveryId) =>
      _uri('inventory/deliveries/${_seg(deliveryId)}');

  Uri openDeliverySession() => _uri('inventory/deliveries/session/open');

  Uri ensureDeliverySession() => _uri('inventory/deliveries/session');

  /// GET for review; PATCH for source/store updates.
  Uri deliverySession(String deliveryId) =>
      _uri('inventory/deliveries/session/${_seg(deliveryId)}');

  Uri finalizeDeliverySession(String deliveryId) =>
      _uri('inventory/deliveries/session/${_seg(deliveryId)}/finalize');

  // Inventory sources (external stock origins; not stock-holding locations).
  Uri sources({bool? includeArchived, int? page, int? perPage}) => _uri(
    'inventory/sources',
    query: {
      if (includeArchived != null) 'include_archived': '$includeArchived',
      if (page != null) 'page': '$page',
      if (perPage != null) 'per_page': '$perPage',
    },
  );

  Uri sourceById(String sourceId) =>
      _uri('inventory/sources/${_seg(sourceId)}');

  Uri restoreSource(String sourceId) =>
      _uri('inventory/sources/${_seg(sourceId)}/restore');
}
