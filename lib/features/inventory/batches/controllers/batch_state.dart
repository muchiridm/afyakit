import 'package:uuid/uuid.dart';
import 'package:afyakit/features/inventory/batches/controllers/batch_like.dart';

class BatchState implements BatchLike {
  @override
  final DateTime? receivedDate;
  @override
  final DateTime? expiryDate;
  @override
  final String? storeId;
  @override
  final String? source;
  @override
  final String quantity;
  @override
  final String editReason;

  const BatchState({
    this.receivedDate,
    this.expiryDate,
    this.storeId,
    this.source,
    this.quantity = '',
    this.editReason = '',
  });

  BatchState copyWith({
    DateTime? receivedDate,
    DateTime? expiryDate,
    String? storeId,
    String? source,
    String? quantity,
    String? editReason,
  }) {
    return BatchState(
      receivedDate: receivedDate ?? this.receivedDate,
      expiryDate: expiryDate ?? this.expiryDate,
      storeId: storeId ?? this.storeId,
      source: source ?? this.source,
      quantity: quantity ?? this.quantity,
      editReason: editReason ?? this.editReason,
    );
  }

  @override
  String generatedId() => const Uuid().v4();
}
