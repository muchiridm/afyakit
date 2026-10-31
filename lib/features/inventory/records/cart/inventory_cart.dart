import 'package:afyakit/features/inventory/batches/inventory_batch.dart';
import 'package:afyakit/features/inventory/records/issues/inventory_issue.dart';

/// One source store per issue; stock is never mutated by the cart.
class InventoryCartLine {
  const InventoryCartLine({required this.batchId, required this.itemId,
    required this.storeId, required this.itemType, required this.quantity,
    required this.availableQuantity});
  final String batchId, itemId, storeId, itemType;
  final int quantity;
  final num availableQuantity;

  InventoryCartLine withQuantity(int quantity) => InventoryCartLine(
    batchId: batchId, itemId: itemId, storeId: storeId,
    itemType: itemType, quantity: quantity,
    availableQuantity: availableQuantity,
  );

  static InventoryCartLine fromBatch(InventoryBatch batch, int quantity) => InventoryCartLine(
    batchId: batch.id, itemId: batch.itemId, storeId: batch.storeId,
    itemType: batch.itemType, quantity: quantity,
    availableQuantity: batch.quantity,
  );
}

class InventoryCart {
  const InventoryCart({this.storeId, this.lines = const {}, this.revision = 0,
    this.requestKey = '', this.payloadFingerprint = '', this.isSubmitting = false});
  final String? storeId;
  final Map<String, InventoryCartLine> lines;
  final int revision;
  final String requestKey;
  final String payloadFingerprint;
  final bool isSubmitting;

  bool get isEmpty => lines.isEmpty;
  int get totalQuantity => lines.values.fold(0, (sum, line) => sum + line.quantity);
  int get batchCount => lines.length;

  InventoryCart copyWith({String? storeId, Map<String, InventoryCartLine>? lines,
    int? revision, String? requestKey, String? payloadFingerprint, bool? isSubmitting}) => InventoryCart(
      storeId: storeId ?? this.storeId, lines: lines ?? this.lines,
      revision: revision ?? this.revision, requestKey: requestKey ?? this.requestKey,
      payloadFingerprint: payloadFingerprint ?? this.payloadFingerprint,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );

  InventoryIssueDraft toDraft({required InventoryIssueType type,
    String? destinationStoreId, String? note}) {
    if (isSubmitting == false && isEmpty) {
      throw const FormatException('Add at least one batch.');
    }
    final draft = InventoryIssueDraft(
      requestKey: requestKey, type: type, fromLocationId: storeId ?? '',
      toLocationId: type == InventoryIssueType.transfer ? destinationStoreId : null,
      note: note,
      entries: lines.values.map((line) => InventoryIssueEntry(
        batchId: line.batchId, itemId: line.itemId, quantity: line.quantity,
      )).toList(growable: false),
    );
    draft.validate();
    return draft;
  }
}
