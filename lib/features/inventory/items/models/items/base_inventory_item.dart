import 'package:afyakit/features/inventory/items/models/has_id.dart';
import 'package:afyakit/features/inventory/items/extensions/item_type_x.dart';

abstract class BaseInventoryItem implements HasId {
  @override
  String? get id;

  String get group;
  String get name;
  String get storeId;

  int? get reorderLevel;
  int? get proposedOrder;

  ItemType get type;
  ItemType get itemType => type;

  /// 🔍 Search terms for indexing
  List<String?> get searchTerms => [name, group];

  /// 🔁 Convert this item into a map for serialization
  Map<String, dynamic> toMap();

  /// 🔄 Clone this item with optional new values
  BaseInventoryItem copyWith({
    String? id,
    String? name,
    String? group,
    int? reorderLevel,
    int? proposedOrder,
  });

  /// 🧬 Clone this item using dynamic field updates
  BaseInventoryItem copyWithFromMap(Map<String, dynamic> fields);
}
