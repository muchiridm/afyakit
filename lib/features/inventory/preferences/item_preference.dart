/// Preference groups are keyed by a dynamic item type and attribute key.
/// Fields come from the
/// app's active InventoryItemType attribute definitions.
class ItemPreferenceKey {
  final String itemType;
  final String field;

  const ItemPreferenceKey(this.itemType, this.field);

  @override
  bool operator ==(Object other) =>
      other is ItemPreferenceKey &&
      itemType == other.itemType && field == other.field;

  @override
  int get hashCode => Object.hash(itemType, field);
}
