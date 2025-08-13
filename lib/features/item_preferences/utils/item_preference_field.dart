enum ItemPreferenceField {
  group,
  formulation,
  route,
  unit,
  package;

  String get key => name;

  String get label {
    switch (this) {
      case ItemPreferenceField.group:
        return 'Group';
      case ItemPreferenceField.formulation:
        return 'Formulation';
      case ItemPreferenceField.route:
        return 'Route';
      case ItemPreferenceField.unit:
        return 'Unit';
      case ItemPreferenceField.package:
        return 'Package';
    }
  }
}
