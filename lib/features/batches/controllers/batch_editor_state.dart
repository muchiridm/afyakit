class BatchEditorState {
  final DateTime? receivedDate;
  final DateTime? expiryDate;
  final String? storeId;
  final String? source;
  final String quantity;
  final String editReason;

  const BatchEditorState({
    this.receivedDate,
    this.expiryDate,
    this.storeId,
    this.source,
    this.quantity = '',
    this.editReason = '',
  });

  BatchEditorState copyWith({
    DateTime? receivedDate,
    DateTime? expiryDate,
    String? storeId, // ← Rename this from 'store'
    String? source,
    String? quantity,
    String? editReason,
  }) {
    return BatchEditorState(
      receivedDate: receivedDate ?? this.receivedDate,
      expiryDate: expiryDate ?? this.expiryDate,
      storeId: storeId ?? this.storeId, // ← now correct
      source: source ?? this.source,
      quantity: quantity ?? this.quantity,
      editReason: editReason ?? this.editReason,
    );
  }
}
