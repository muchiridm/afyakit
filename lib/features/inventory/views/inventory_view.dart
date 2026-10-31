/// Modes for the canonical stock workspace.
enum InventoryMode {
  stockIn,
  stockOut;

  bool get isStockIn => this == InventoryMode.stockIn;
  bool get isStockOut => this == InventoryMode.stockOut;
  String get label => isStockIn ? 'Stock In' : 'Stock Out';
}
