import 'package:afyakit/modules/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/modules/inventory/preferences/utils/item_preference_field.dart';

final Map<ItemType, List<ItemPreferenceField>> preferenceFieldsByType = {
  ItemType.medication: [
    ItemPreferenceField.group,
    ItemPreferenceField.formulation,
    ItemPreferenceField.route,
  ],
  ItemType.consumable: [
    ItemPreferenceField.group,
    ItemPreferenceField.package,
    ItemPreferenceField.unit,
  ],
  ItemType.equipment: [],
};
