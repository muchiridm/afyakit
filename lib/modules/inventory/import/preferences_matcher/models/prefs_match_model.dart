import 'package:afyakit/modules/inventory/import/preferences_matcher/models/field_match_model.dart';
import 'package:afyakit/modules/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/modules/inventory/preferences/utils/item_preference_field.dart';

class PrefsMatchModel {
  PrefsMatchModel(this.type, this.byField);

  final ItemType type;
  final Map<ItemPreferenceField, FieldMatchModel> byField;

  bool get isComplete => byField.values.every(
    (f) =>
        f.incoming.every((raw) => (f.selections[raw] ?? '').trim().isNotEmpty),
  );
}
