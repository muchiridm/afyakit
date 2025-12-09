abstract class InventoryEditableController {
  Future<void> setProposedOrder(String itemId, int value);
  Future<void> setReorderLevel(String itemId, int value);

  /// Optional — only for ConsumableItem
  Future<void> setPackSize(String itemId, String value);

  /// Optional — only for ConsumableItem
  Future<void> setPackage(String itemId, String value);
}
