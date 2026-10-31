// Canonical inventory items and dynamic type definitions.
class InventoryAttribute {
  final String key, label, dataType;
  final bool required;
  const InventoryAttribute({required this.key, required this.label, required this.dataType, required this.required});

  factory InventoryAttribute.fromJson(Map<String, dynamic> x) => InventoryAttribute(
    key: x['key'] as String? ?? '', label: x['label'] as String? ?? '',
    dataType: x['data_type'] as String? ?? 'string', required: x['required'] == true,
  );
  Map<String, dynamic> toJson() => {'key': key, 'label': label, 'data_type': dataType, 'required': required};
}

class InventoryItemType {
  final String typeId, label;
  final bool isActive;
  final List<InventoryAttribute> attributes;
  const InventoryItemType({required this.typeId, required this.label, required this.isActive, required this.attributes});
  factory InventoryItemType.fromJson(Map<String, dynamic> x) => InventoryItemType(
    typeId: x['type_id'] as String? ?? '', label: x['label'] as String? ?? '',
    isActive: x['is_active'] == true,
    attributes: (x['attributes'] as List? ?? const []).map((v) => InventoryAttribute.fromJson(Map<String, dynamic>.from(v as Map))).toList(),
  );
}

class InventoryItem {
  final String id, itemType, name;
  final num? reorderLevel, proposedOrder;
  final bool isArchived;
  final Map<String, dynamic> attributes;
  const InventoryItem({required this.id, required this.itemType, required this.name,
    this.reorderLevel, this.proposedOrder, required this.isArchived, required this.attributes});
  factory InventoryItem.fromJson(Map<String, dynamic> x) => InventoryItem(
    id: (x['item_id'] ?? x['id'] ?? '').toString(),
    itemType: x['item_type'] as String? ?? '', name: x['name'] as String? ?? '',
    reorderLevel: x['reorder_level'] as num?,
    proposedOrder: x['proposed_order'] as num?, isArchived: x['is_archived'] == true,
    attributes: Map<String, dynamic>.from(x['attributes'] as Map? ?? const {}),
  );
}

class InventoryItemInput {
  final String itemType, name;
  final num? reorderLevel, proposedOrder;
  final Map<String, dynamic> attributes;
  const InventoryItemInput({required this.itemType, required this.name,
    this.reorderLevel, this.proposedOrder, this.attributes = const {}});
  Map<String, dynamic> toJson() => {
    'item_type': itemType, 'name': name.trim(),
    if (reorderLevel != null) 'reorder_level': reorderLevel,
    if (proposedOrder != null) 'proposed_order': proposedOrder,
    'attributes': attributes,
  };
}

class InventoryPage {
  final List<InventoryItem> items;
  final bool hasMore;
  final int page;
  const InventoryPage(this.items, this.hasMore, this.page);
}
