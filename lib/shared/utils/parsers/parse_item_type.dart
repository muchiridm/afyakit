import 'package:afyakit/modules/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/shared/utils/normalize/normalize_string.dart';

ItemType parseItemType(dynamic raw) {
  if (raw is String) {
    final normalized = raw.normalize();
    return ItemType.values.firstWhere(
      (t) => t.name.normalize() == normalized,
      orElse: () => ItemType.unknown,
    );
  }
  return ItemType.unknown;
}
