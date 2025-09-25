import 'package:afyakit/core/inventory/extensions/item_type_x.dart';
import 'package:afyakit/core/records/issues/extensions/issue_type_x.dart';

class CartState {
  final Map<String, Map<String, int>> batchQuantities;
  final String? fromStore; // ✅ NEW
  final String? destination;
  final String note;
  final DateTime requestDate;
  final IssueType type;
  final ItemType itemType;

  const CartState({
    required this.batchQuantities,
    this.fromStore, // ✅ NEW
    this.destination,
    this.note = '',
    required this.requestDate,
    this.type = IssueType.dispense,
    required this.itemType,
  });

  factory CartState.empty(ItemType itemType) => CartState(
    batchQuantities: {},
    fromStore: null, // ✅ Init here too
    destination: null,
    note: '',
    requestDate: DateTime.now(),
    type: IssueType.dispense,
    itemType: itemType,
  );

  CartState copyWith({
    Map<String, Map<String, int>>? batchQuantities,
    String? fromStore, // ✅ Allow override
    String? destination,
    String? note,
    DateTime? requestDate,
    IssueType? type,
    ItemType? itemType,
  }) {
    return CartState(
      batchQuantities: batchQuantities ?? this.batchQuantities,
      fromStore: fromStore ?? this.fromStore, // ✅ Set value
      destination: destination ?? this.destination,
      note: note ?? this.note,
      requestDate: requestDate ?? this.requestDate,
      type: type ?? this.type,
      itemType: itemType ?? this.itemType,
    );
  }

  bool get isEmpty => batchQuantities.isEmpty;
  bool get isNotEmpty => batchQuantities.isNotEmpty;

  int get totalQuantity {
    return batchQuantities.values
        .map((batchMap) => batchMap.values.fold(0, (a, b) => a + b))
        .fold(0, (a, b) => a + b);
  }
}
