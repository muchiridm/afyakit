// lib/features/src/inventory_view/utils/inventory_mode_enum.dart

enum InventoryMode {
  stockIn,
  stockOut;

  String get label => switch (this) {
    InventoryMode.stockIn => 'Stock In',
    InventoryMode.stockOut => 'Stock Out',
  };

  bool get isStockIn => this == InventoryMode.stockIn;
  bool get isStockOut => this == InventoryMode.stockOut;
}
