// File: lib/shared/utils/parse/domain/item_type.dart
import 'package:afyakit/features/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/shared/utils/normalize/normalize_string.dart';

/// Parses ItemType from arbitrary input.
/// - strings are normalized using your `normalize()`
/// - returns ItemType.unknown if not recognized
ItemType parseItemType(Object? raw) {
  final s = (raw is String) ? raw : raw?.toString();
  if (s == null) return ItemType.unknown;

  final normalized = s.normalize();
  if (normalized.isEmpty) return ItemType.unknown;

  return ItemType.values.firstWhere(
    (t) => t.name.normalize() == normalized,
    orElse: () => ItemType.unknown,
  );
}
