// lib/core/api/afyakit/routes/routes_inventory.dart

part of 'routes.dart';

extension AfyaKitInventoryRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 📦 Inventory items
  // ─────────────────────────────────────────────

  Uri inventory(String itemType) =>
      _uri('inventory/items', query: {'type': itemType});

  Uri createItem() => _uri('inventory/items');

  Uri itemById(String id, {String? type}) => _uri(
    'inventory/items/${_seg(id)}',
    query: (type != null && type.trim().isNotEmpty)
        ? {'type': type.trim()}
        : null,
  );

  // ─────────────────────────────────────────────
  // ⚙️ Preferences
  // ─────────────────────────────────────────────

  Uri preferenceField(String itemType, String field) =>
      _uri('inventory/preferences/${_seg(itemType)}/${_seg(field)}');

  // ─────────────────────────────────────────────
  // 📍 Inventory locations
  // ─────────────────────────────────────────────

  Uri getTypedLocations(InventoryLocationType type) =>
      _uri('inventory/locations/${type.asString}');

  Uri addTypedLocation(InventoryLocationType type) =>
      _uri('inventory/locations/${type.asString}');

  Uri deleteTypedLocation(InventoryLocationType type, String id) =>
      _uri('inventory/locations/${type.asString}/${_seg(id)}');

  // ─────────────────────────────────────────────
  // 🧪 Batches
  // ─────────────────────────────────────────────

  Uri listBatches(String storeId) =>
      _uri('inventory/stores/${_seg(storeId)}/batches');

  Uri createBatch(String storeId) =>
      _uri('inventory/stores/${_seg(storeId)}/batches');

  Uri updateBatch(String storeId, String batchId) =>
      _uri('inventory/stores/${_seg(storeId)}/batches/${_seg(batchId)}');

  Uri deleteBatch(String storeId, String batchId) =>
      _uri('inventory/stores/${_seg(storeId)}/batches/${_seg(batchId)}');

  // ─────────────────────────────────────────────
  // 📥 Imports
  // ─────────────────────────────────────────────

  Uri importInventory({
    required String type,
    bool dryRun = true,
    bool persist = false,
  }) => _uri(
    'inventory/imports/inventory',
    query: {'type': type, 'dryRun': '$dryRun', 'persist': '$persist'},
  );

  Uri importInventoryRaw({
    required String type,
    bool dryRun = true,
    bool persist = false,
  }) => _uri(
    'inventory/imports/inventory-raw',
    query: {'type': type, 'dryRun': '$dryRun', 'persist': '$persist'},
  );

  Uri importTemplate(String type) =>
      _uri('inventory/imports/templates/${_seg(type)}');

  // ─────────────────────────────────────────────
  // 📤 Issues
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

  Uri disposeIssue(String issueId) =>
      _uri('inventory/issues/${_seg(issueId)}/dispose');

  Uri dispenseIssue(String issueId) =>
      _uri('inventory/issues/${_seg(issueId)}/dispense');

  // ─────────────────────────────────────────────
  // 🚚 Deliveries
  // ─────────────────────────────────────────────

  /// Finalized delivery records.
  Uri deliveries() => _uri('inventory/deliveries');

  Uri deliveryById(String deliveryId) =>
      _uri('inventory/deliveries/${_seg(deliveryId)}');

  /// Current authenticated user's open delivery session.
  Uri openDeliverySession() => _uri('inventory/deliveries/session/open');

  /// Ensure/resume an active delivery session.
  Uri ensureDeliverySession() => _uri('inventory/deliveries/session');

  /// Update last store/source context on an open delivery.
  Uri updateDeliverySession(String deliveryId) =>
      _uri('inventory/deliveries/session/${_seg(deliveryId)}');

  /// Review the authoritative backend delivery summary.
  Uri reviewDeliverySession(String deliveryId) =>
      _uri('inventory/deliveries/session/${_seg(deliveryId)}');

  /// Finalize the delivery and create the final delivery record.
  Uri finalizeDeliverySession(String deliveryId) =>
      _uri('inventory/deliveries/session/${_seg(deliveryId)}/finalize');
}
