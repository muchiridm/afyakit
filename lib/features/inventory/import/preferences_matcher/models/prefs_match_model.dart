import 'package:afyakit/features/inventory/import/preferences_matcher/models/field_match_model.dart';
import 'package:afyakit/features/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/features/inventory/preferences/utils/item_preference_field.dart';

class PrefsMatchModel {
  PrefsMatchModel(this.type, this.byField);

  final ItemType type;
  final Map<ItemPreferenceField, FieldMatchModel> byField;

  bool get isComplete => byField.values.every(
    (f) =>
        f.incoming.every((raw) => (f.selections[raw] ?? '').trim().isNotEmpty),
  );
}
