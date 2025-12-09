import 'package:afyakit/modules/inventory/items/extensions/item_type_x.dart';

enum ImportType { medication, consumable, equipment }

extension ImportTypeMapper on ImportType {
  ItemType toItemType() {
    switch (this) {
      case ImportType.medication:
        return ItemType.medication;
      case ImportType.consumable:
        return ItemType.consumable;
      case ImportType.equipment:
        return ItemType.equipment;
    }
  }
}
