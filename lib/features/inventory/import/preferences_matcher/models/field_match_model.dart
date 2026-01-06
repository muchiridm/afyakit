import 'package:afyakit/features/inventory/preferences/utils/item_preference_field.dart';

class FieldMatchModel {
  FieldMatchModel({
    required this.field,
    required this.incoming,
    required this.existing,
    required this.selections,
  });

  final ItemPreferenceField field;
  final List<String> incoming; // from import (deduped)
  final List<String> existing; // from preferences (sorted)
  final Map<String, String> selections; // incoming -> canonical
}
