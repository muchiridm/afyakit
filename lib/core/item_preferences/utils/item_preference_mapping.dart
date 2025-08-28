import 'package:afyakit/core/inventory/models/item_type_enum.dart';
import 'package:afyakit/core/item_preferences/utils/item_preference_field.dart';

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
