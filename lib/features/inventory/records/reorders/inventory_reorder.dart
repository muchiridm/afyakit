import 'package:afyakit/features/inventory/items/inventory_item.dart';

/// Procurement proposal only. It is not a stock movement or a saved PO.
class InventoryReorderLine {
  final String itemId;
  final String itemType;
  final String name;
  final int quantity;

  const InventoryReorderLine({
    required this.itemId,
    required this.itemType,
    required this.name,
    required this.quantity,
  });

  InventoryReorderLine copyWith({int? quantity}) => InventoryReorderLine(
        itemId: itemId,
        itemType: itemType,
        name: name,
        quantity: quantity ?? this.quantity,
      );

  factory InventoryReorderLine.fromItem(InventoryItem item, int quantity) =>
      InventoryReorderLine(
        itemId: item.id,
        itemType: item.itemType,
        name: item.name,
        quantity: quantity,
      );
}

class InventoryReorderDraft {
  final Map<String, InventoryReorderLine> lines;
  final String note;

  const InventoryReorderDraft({this.lines = const {}, this.note = ''});

  int get totalUnits => lines.values.fold(0, (sum, line) => sum + line.quantity);
  int get itemCount => lines.length;

  List<InventoryReorderLine> get sortedLines {
    final result = lines.values.toList();
    result.sort((a, b) {
      final category = a.itemType.compareTo(b.itemType);
      return category != 0 ? category : a.name.compareTo(b.name);
    });
    return result;
  }
}
